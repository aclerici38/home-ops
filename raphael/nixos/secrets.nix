_: {
  sops.defaultSopsFile = ../secrets.sops.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets = {
    anthony-password-hash = {
      neededForUsers = true;
    };
  };
}
