{ config, ... }:
{
  sops.defaultSopsFile = ../secrets.sops.yaml;

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets."llmkube/kubeconfig" = {
    # Read by the metal agent LaunchDaemon, which runs as root.
    owner = "root";
    mode = "0400";
  };

  homeOps.llmkube.kubeconfig = config.sops.secrets."llmkube/kubeconfig".path;
}
