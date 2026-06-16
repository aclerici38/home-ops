# Talos

Talos machine configuration, split per cluster and generated with
[talhelper](https://github.com/budimanjojo/talhelper).

## Layout

```
talos/
├── global/   # patches shared, byte-identical, by both clusters
├── home/     # dormammu — on-prem multi-node cluster (bonds/cain/posey/belt)
└── cloud/    # madbum — single-node Oracle Cloud (OCI) ARM control plane
```

Each cluster directory holds its own `talconfig.yaml`, `talsecret.sops.yaml`,
`patches/`, and generated `clusterconfig/`. The two clusters are independent
(separate secrets / CA / etcd).

- **home** pulls its variables from the repo-root `globals.env` (injected by
  mise, and also consumed by Flux). Its node networking lives in
  `patches/networking/`.
- **cloud** is fully inlined (no `talenv`); only `TALOS_VERSION` /
  `KUBE_VERSION` come from `globals.env` so both clusters track the same
  versions. eth0 is configured by the Oracle platform over DHCP, so there is no
  networking patch. `talhelper`'s `ipAddress` is the node's public (NAT) IP so
  talosctl is reachable from outside OCI; kubelet/etcd bind the private
  `10.40.40.0/24` subnet.

`global/` holds the shared patches. Some are fully identical
(`machine-features.yaml`, `machine-kernel.yaml`,
`admission-controller-patch.yaml`, `controller-machine-features.yaml`). Others
(`cluster.yaml`, `machine-kubelet.yaml`, `machine-network.yaml`) are a shared
**base** that omits the one cluster-specific key; each cluster then layers a
small override patch from its own `patches/` *after* the base in the talconfig
patch list (talhelper merges patches in order):

| shared base (`global/`) | per-cluster override (`<cluster>/patches/`)        |
| ----------------------- | -------------------------------------------------- |
| `cluster.yaml`          | `controller/etcd.yaml` — etcd advertised/listen subnets |
| `machine-kubelet.yaml`  | `global/machine-kubelet.yaml` — `nodeIP.validSubnets`   |
| `machine-network.yaml`  | `global/machine-network.yaml` — `nameservers`           |

Patches that differ wholesale per cluster (sysctls, NTP, files, networking)
stay entirely under each cluster's `patches/`.

## Switching clusters

The default is the **home** cluster. `talos/cloud/.mise.toml` makes both tools
follow your `pwd` while under `talos/cloud` (applied by mise on `cd`):

- **talosctl** — `TALOSCONFIG` env is swapped to the cloud cluster's config
  (talhelper keeps a separate talosconfig per cluster), reverting on leave.
- **kubectl / k9s** — the cloud cluster is the `admin@madbum` context inside the
  default `~/.kube/config` (no separate kubeconfig). `enter`/`leave` hooks run
  `kubectl config use-context` to flip the active context to `admin@madbum` on
  entry and back to `admin@dormammu` on leave, so k9s just shows the right
  cluster. Merge the context in once after bootstrap with `talosctl kubeconfig`.

A new checkout must `mise trust talos/cloud/.mise.toml` once.

## Tasks

```sh
mise run talos:gen   [home|cloud]          # regenerate clusterconfig/ (default home)
mise run talos:apply [home|cloud] [node]   # diff-check then apply (default home)
```
