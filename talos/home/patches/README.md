# Talos Patching

Patches referenced by `../talstomize.yaml`. They are plain [Talos machine config
patches](https://www.talos.dev/v1.14/talos-guides/configuration/patching/) —
strategic-merge documents, applied in the order the config lists them.

## Layering

talstomize applies patches per node in a fixed order, each layer overriding the
one before it:

1. `patches:` — every node in this cluster
2. `controlplanePatches:` / `workerPatches:` — that node's role
3. `nodes.<name>.patches:` — that one node

Shared-across-clusters patches live in `../../global/` and are pulled in by both
this cluster and `talos/cloud`; the directories here hold the home-cluster half
of each pair (e.g. `../../global/machine-kubelet.yaml` then
`global/machine-kubelet.yaml`).

## Directories

- `global/` — applied to every node in this cluster
- `controller/` — applied to control-plane nodes only
- `worker/` — applied to worker nodes only
- `networking/` — one file per node, referenced from that node's `patches:`

Anything genuinely per-node (install disk, node-only kernel modules) stays
inline in `../talstomize.yaml`; anything shared by a role belongs in
`controller/` or `worker/` rather than being repeated on each node.
