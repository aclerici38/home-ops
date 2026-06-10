# apps/

**Payload only.** Each `apps/<namespace>/<component>/` holds the manifests for one component
(HelmRelease, ConfigMaps, the chart's source `repo.yaml`, etc.). These dirs are *not* reconciled
directly — a Flux `Kustomization` in [`../kustomizations/`](../kustomizations) points its `path` at
each one and builds it into the cluster from the `flux-system` GitRepository.

```
apps/<namespace>/
  <component>/            # payload — NO kustomization.yaml (kustomize-controller auto-generates one)
    …manifests
```

- **No `kustomization.yaml` in payload dirs** — Flux auto-generates one over the `path`.
- **The control plane lives in [`../kustomizations/`](../kustomizations)** (one folder per namespace,
  mirroring this tree): the namespace's `namespace.yaml` plus a `Kustomization` per component.

## Reconcile path

```
GitRepository flux-system
  └─▶ Kustomization "apps" (flux/cluster/apps.yaml, path ./kubernetes/kustomizations)
        └─▶ applies kustomizations/<namespace>/{namespace.yaml, <component>.yaml…}
              └─▶ each Kustomization builds path ./kubernetes/apps/<namespace>/<component>
                    └─▶ into targetNamespace: <namespace>
```

Everything is delivered from the single `flux-system` GitRepository — no per-namespace OCI artifacts.
Because the `apps` Kustomization only ever scans `kubernetes/kustomizations` (control-plane CRs), it
never double-applies the payload, and the whole tree renders offline with `mise run flate-test`.
