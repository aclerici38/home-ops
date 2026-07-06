{ config, ... }:
# sops-nix: age key = the host's SSH key (generated at install), so there's no
# separate key to place. Bootstrap note in README: secrets.sops.yaml is currently
# encrypted to the repo age key; after first boot, add the host key as a recipient
# (ssh-to-age /etc/ssh/ssh_host_ed25519_key.pub) and `sops updatekeys`.
{
  sops.defaultSopsFile = ../secrets.sops.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/keys.txt"; # bootstrap: repo age key lives here

  sops.secrets.cloudflare-token = { };
  sops.secrets.towonel-invite-token = { };

  sops.templates."caddy.env" = {
    content = "CF_API_TOKEN=${config.sops.placeholder.cloudflare-token}";
    owner = "caddy";
    mode = "0400";
  };
  sops.templates."towonel.env" = {
    content = "TOWONEL_INVITE_TOKEN=${config.sops.placeholder.towonel-invite-token}";
    mode = "0400";
  };
}
