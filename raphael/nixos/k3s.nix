{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # renovate: datasource=repology depName=nix_unstable/k3s versioning=loose
  k3sMinor = "1.34";

  # "1.34" -> attribute name "k3s_1_34"
  k3sSlot = "k3s_" + lib.replaceStrings [ "." ] [ "_" ] k3sMinor;

  # Pull k3s from unstable
  k3sPkgs = inputs.nixpkgs-k3s.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  services.k3s = {
    enable = true;
    role = "server";
    package = k3sPkgs.${k3sSlot};

    extraFlags = [
      "--disable=traefik"
      "--disable=coredns"
      "--flannel-backend=host-gw"
      "--disable-network-policy"
      "--disable-helm-controller"
      "--egress-selector-mode=disabled"
      "--write-kubeconfig-mode=0600"

      "--kubelet-arg=image-gc-high-threshold=75" # start pruning images at 75% imagefs
      "--kubelet-arg=image-gc-low-threshold=60" # prune down to 60%
      "--kubelet-arg=system-reserved=cpu=200m,memory=256Mi"
      "--kubelet-arg=eviction-hard=memory.available<100Mi,nodefs.available<10%,imagefs.available<10%"

      "--kubelet-arg=node-status-update-frequency=20s"
      "--kube-controller-manager-arg=node-monitor-period=20s"
      "--kube-controller-manager-arg=node-monitor-grace-period=1m"
      "--kube-apiserver-arg=event-ttl=30m"
    ];
  };

  # Firewall: allow the apiserver and never filter Cilium/pod interfaces.
  networking.firewall = {
    allowedTCPPorts = [ 6443 ];
    trustedInterfaces = [ "cni0" ];
  };
}
