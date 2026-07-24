# OpenCloud — High Availability

Status and remaining work to make OpenCloud survive a single-node loss.

OpenCloud runs here as the **monolithic** binary (`opencloud server` — all services in
one process) with state externalized to a dedicated **NATS** cluster and storage split
between **CephFS** (decomposed metadata) and **versitygw** S3 (blobs). Achieving HA means
replicating that middleware, running >1 app replica, and peeling off the couple of
services that can't be cloned.

## Architecture at a glance

| Concern | Backend | Notes |
|---|---|---|
| Service registry / cache / persistent-store / events | NATS JetStream (`nats-js-kv`) | `nats/` HelmRelease, 3 pods |
| File metadata | decomposed on CephFS RWX (`opencloud` PVC) | multi-writer via POSIX `flock` |
| File blobs | versitygw S3 (`opencloud` bucket) | posix backend on `backups` volume |
| Auth (IDP) | external — `id.clerici.tech` | `idp` service excluded already |
| User directory (IDM) | built-in `idm` (`idm.boltdb`) | split-out singleton `idm` controller — see below |
| Full-text search | bleve on CephFS (`search` index dir) | split-out singleton `search` controller — see below |

## Done

- [x] **NATS 3-node JetStream cluster** (`nats/hr.yaml`) — topology-spread + PDB.
- [x] **Backends externalized to NATS** — `MICRO_REGISTRY`, `OC_CACHE_STORE`,
      `OC_PERSISTENT_STORE`, `OC_EVENTS_ENDPOINT` all `nats-js-kv` (commit `5a48ce12`).
- [x] **Metadata on RWX CephFS** — `opencloud` PVC is `ReadWriteMany`, so multiple
      app replicas can share it.
- [x] **NATS stream replication → R=3** (`nats/cronjob.yaml`) — see below.
- [x] **Un-scalable services split out** (`app/hr.yaml`) — `idm` and `search` are now
      dedicated single-replica (`strategy: Recreate`) controllers in the same
      app-template HelmRelease, both excluded from the app tier via
      `OC_EXCLUDE_RUN_SERVICES: …,search,idm`. See "Split-out services" below.

### NATS R=3 CronJob — why it exists

OpenCloud creates every JetStream stream/KV at **`replicas: 1`**, pinned to one node.
With a 3-node cluster that's still a SPOF: lose that node and registry/events/locks
vanish. There is **no env/arg** to change this — on either side:

- OpenCloud/oCIS hardcodes R=1 (`go-micro` only creates-if-absent, never updates);
  the feature request was closed and punted to the deployment layer
  (owncloud/ocis#7023, #7272, ocis-charts#472 → NACK).
- NATS has no server-side "default replicas" setting; it's strictly per-stream.

A NACK controller is overkill for one workload, so `cronjob.yaml` bumps the streams to
R=3 out-of-band every 15 min (idempotent). This is durable: OpenCloud never rewrites an
existing stream, so R=3 sticks; the CronJob only re-asserts it after a rare
recreation / DR rebuild.

## Split-out services (done)

The monolith runs *every* service per replica. Two can't be cloned, so they are now
separate single-replica controllers (`strategy: Recreate`) in the app-template
HelmRelease, above `collabora`. Both share the `opencloud` PVC — `/etc/opencloud`
(config subPath, for the `opencloud init`-generated secrets: JWT, machine-auth,
transfer, service-account, LDAP bind/admin passwords) and `/var/lib/opencloud`
(data subPath, for their on-disk state). Nothing needed migrating.

- **`search` controller** — `opencloud search server`, grpc `:9220`, debug `:9224`.
  Owns the bleve index (`data/search`). Discovered by the app tier purely through the
  NATS registry (pod IP), so it needs **no Service**. Gets the NATS registry/events/store
  env, the tika extractor, and `OC_SERVICE_ACCOUNT_*` (to read files for indexing).
  *(Only genuinely un-scalable service upstream — bleve keeps an exclusive index write
  lock. `SEARCH_ENGINE_BLEVE_SCALE=true` or the OpenSearch backend would make it
  scalable; future, needs a cluster.)*
- **`idm` controller + `opencloud-idm` Service** — `opencloud idm server`, LDAPS `:9235`,
  debug `:9239`. `idm.boltdb` (bbolt) takes an **exclusive file lock**, so it must stay
  a singleton. The app tier reaches it over the Service via
  `OC_LDAP_URI=ldaps://opencloud-idm.opencloud.svc.cluster.local:9235`.
  **Decision: keep built-in idm, no external LDAP** — lldap wouldn't reduce management
  (its SQLite is also a SPOF unless backed by HA Postgres) and OpenCloud already drives
  user CRUD via Graph API + OIDC autoprovision. idm stays a deliberate singleton.

### LDAPS cert — why cert-manager, not the autogen cert

idm auto-generates its LDAPS cert with SANs `127.0.0.1` / `localhost` only
(`pkg/crypto/gencert.go`), which the monolith relied on by talking to
`ldaps://localhost:9235` in-process. Once idm is a separate pod, the app tier connects
by **Service DNS**, so that cert fails verification. Rather than set `OC_LDAP_INSECURE`
(encrypted but unverified), `app/pki.yaml` mints a proper cert the same way the upstream
Helm chart does — a cert-manager self-signed **CA → leaf** with the `opencloud-idm`
service SANs. idm serves it via `IDM_LDAPS_CERT/KEY` (mounted from the
`opencloud-idm-ldaps` secret at `/etc/ldap-cert`); the app tier trusts it via
`OC_LDAP_CACERT=/etc/ldap-cert/ca.crt` (ca.crt-only subPath mount, so the app pods never
see the private key). The CA is 5y and stable, so leaf rotation never breaks clients.

## Remaining work

Ordered least-risk first. Load-test each stage before the next.

### 1. Scale the app tier
- [ ] `replicas: 2` (or 3) with `OC_EXCLUDE_RUN_SERVICES: idp,ocm,nats,search,idm`.
- [ ] **Anti-affinity / topologySpreadConstraints** across the 4 nodes.
- [ ] **NATS-readiness gate** — plain initContainer that blocks until NATS answers
      (`nats stream ls`), eliminating the startup race where OpenCloud tears itself down
      if NATS isn't ready. *(Decided: plain initContainer, not a sidecar — replica-setting
      stays in the CronJob so it isn't multiplied per replica.)*
- [ ] **Init race** — `opencloud init || true` runs on every pod against shared
      `/etc/opencloud`. Move to a one-shot Flux-ordered Job / guarded init.
- [ ] **⚠️ Validate multi-writer metadata.** `storage-users` / `storage-system` rely on
      POSIX `flock` on CephFS for concurrency. Rook's kernel client supports it, but this
      is the **least-proven** path — hammer concurrent writes/shares from both replicas
      before trusting it.

### 2. Blob backend (versitygw) SPOF
- [ ] Scale versitygw to 2+ replicas (stateless S3↔posix gateway) + anti-affinity + PDB.
- [ ] **Hard limit:** the backing `backups` zfs-ssd volume is a single PVC — the
      underlying ZFS host stays a storage-layer SPOF. True blob HA = separate, bigger track.

### 3. Editing stack  *(optional — file access HA doesn't depend on it)*
- [ ] `wopi` (collaboration) → 2 replicas + anti-affinity (stateless via NATS).
- [ ] `collabora` → 2 replicas, but sessions are document-sticky → needs route affinity;
      Collabora clustering is limited. Lowest priority.

### 4. HA hygiene
- [ ] **PodDisruptionBudgets** — app tier (`minAvailable: 1`), versitygw, wopi.
      Singletons (idm/search) get none.
- [ ] Confirm NATS PDB allows only 1 unavailable (correct for 3-node R=3 quorum).
- [ ] **Init/first-boot ordering:** idm and search now mount the shared config
      subPath and depend on `opencloud init` having already populated it. Today the
      app-tier `opencloud init || true` seeds it and the config already exists on the
      PVC; once the init race (step 1) is moved to a one-shot Job, order it before all
      three tiers (init Job → idm/search + app tier).
- [ ] Clean up the leftover embedded-`nats/` dir in the data volume.

## Accepted tradeoffs / residual SPOFs

- **`idm`** — single replica; ~seconds-long blip in user resolution on reschedule
  (softened by the NATS userinfo cache). Acceptable since real auth is external OIDC.
- **`search`** — single replica by necessity (bleve). Search briefly unavailable during
  its reschedule; file access unaffected.
- **versitygw backing volume** and **Ceph/Rook** themselves — genuine storage-layer HA is
  out of scope for this effort.

## References

- HA/scaling discussion — <https://github.com/orgs/opencloud-eu/discussions/1231>
- NATS stream replicas — <https://github.com/owncloud/ocis/issues/7023>,
  <https://github.com/owncloud/ocis/issues/7272>,
  <https://github.com/owncloud/ocis-charts/pull/472>
