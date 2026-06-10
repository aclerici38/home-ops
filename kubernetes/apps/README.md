# apps/

**Folder == namespace.** Each `apps/<namespace>/` holds one namespace, delivered as a single
OCI artifact. Manifests are packaged to OCI by CI; Flux pulls them — it does not read them from
git. Only `deploy/` is reconciled from git.

```
apps/<namespace>/
  deploy/                 # git-reconciled control plane (one resource per file)
    repository.yaml       #   OCIRepository — the namespace's manifest artifact (oci://…/<namespace>)
    <component>.yaml      #   a Kustomization per component, sourcing that OCIRepository
  <component>/            # OCI payload — NO kustomization.yaml (kustomize-controller auto-generates)
    …manifests
```

Example — `cilium/` has two components off one artifact: `deploy/app.yaml` (`path ./app`) and
`deploy/networking.yaml` (`path ./networking`, `dependsOn` the first).

## Rules

- **`deploy/` = control plane, the rest = payload.** Everything outside `deploy/` is OCI-delivered.
- **No `kustomization.yaml` in payload dirs** — Flux auto-generates one over the `path`.
- **`path:` is artifact-relative** (`./app`), not git-relative.
- **One OCIRepository per namespace**, shared by all that namespace's Kustomizations.
- The repo-root **`.sourceignore`** keeps payload dirs out of the Flux git artifact, so the `apps`
  Kustomization only ever applies `deploy/` CRs (never double-applying manifests from git).

## Reconcile path

```
GitRepository ─▶ Kustomization "apps" (flux/cluster/apps.yaml, path ./kubernetes/apps)
             ─▶ applies <namespace>/deploy/*.yaml
                  ├─ OCIRepository  ──pulls──▶ oci://…/<namespace>:main
                  └─ Kustomization(s) ─builds path─▶ payload into the namespace
```

## CI

On a change under `apps/<namespace>/`, CI packages that folder, moves the mutable `main` tag, and
pokes a `generic-hmac` Receiver to reconcile now.
