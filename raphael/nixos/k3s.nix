{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # renovate: datasource=repology depName=nix_unstable/k3s versioning=loose
  k3sMinor = "1.35";

  # "1.34" -> attribute name "k3s_1_34"
  k3sSlot = "k3s_" + lib.replaceStrings [ "." ] [ "_" ] k3sMinor;

  # Pull k3s from unstable
  k3sPkgs = inputs.nixpkgs-k3s.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Address kubectl reaches the API server at from off-box
  apiHost = "raphael.clerici.tech";
in
{
  services.k3s = {
    enable = true;
    role = "server";
    package = k3sPkgs.${k3sSlot};

    extraFlags = [
      "--disable=traefik"
      "--flannel-backend=host-gw"
      "--disable-network-policy"
      "--disable-helm-controller"
      "--egress-selector-mode=disabled"
      "--write-kubeconfig-mode=0600"
      "--tls-san=${apiHost}"
      "--tls-san=raphael"

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

  # Firewall: allow the apiserver and never filter the flannel bridge.
  networking.firewall = {
    allowedTCPPorts = [ 6443 ];
    trustedInterfaces = [ "cni0" ];
  };
  systemd.services.k3s-kubeconfig = {
    description = "Emit a named, remotely-usable kubeconfig (raphael)";
    after = [ "k3s.service" ];
    requires = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      src=/etc/rancher/k3s/k3s.yaml
      dst=/etc/rancher/k3s/raphael.yaml
      # k3s writes its kubeconfig shortly after the service comes up.
      for _ in $(seq 1 30); do [ -s "$src" ] && break; sleep 1; done
      [ -s "$src" ] || { echo "k3s.yaml not written yet" >&2; exit 1; }
      umask 077
      ${pkgs.yq-go}/bin/yq '
        .clusters[0].name = "raphael" |
        .users[0].name = "raphael" |
        .contexts[0].name = "raphael" |
        .contexts[0].context.cluster = "raphael" |
        .contexts[0].context.user = "raphael" |
        .current-context = "raphael" |
        .clusters[0].cluster.server = "https://${apiHost}:6443"
      ' "$src" > "$dst"
    '';
  };
}
