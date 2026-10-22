{ config, lib, ... }:
let
  # The 1Password-held key the MacBook Pro already signs with. GitHub has it
  # registered as both an authentication and a signing key.
  githubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMQZpI+1xsgzCGDYQunXKq0Pfgc5pYaSQ86tiJv0Fh/";
in
{
  programs.git = {
    enable = true;
    config = {
      user = {
        name = "aclerici38";
        email = "anthony@clerici.me";
        signingkey = "key::${githubKey}";
      };
      gpg.format = "ssh";
      gpg.ssh = {
        program = lib.getExe' config.programs._1password-gui.package "op-ssh-sign";
        allowedSignersFile = "/etc/git/allowed_signers";
      };
      commit.gpgsign = true;
      tag.gpgsign = true;
      # Reject corrupt or malformed objects on every fetch, clone and push.
      transfer.fsckObjects = true;
      # Pushes always go over SSH; https clones (and comin) are left alone.
      url."git@github.com:".pushInsteadOf = "https://github.com/";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
  # Lets `git log --show-signature` verify our own signatures locally.
  environment.etc."git/allowed_signers".text = "anthony@clerici.me ${githubKey}\n";
  environment.etc."ssh/github.pub".text = "${githubKey}\n";

  # Pin GitHub's host key (api.github.com/meta) and refuse anything else
  # instead of prompting. Only offer the GitHub key, not every key in the vault.
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  programs.ssh.extraConfig = ''
    Host github.com
      StrictHostKeyChecking yes
      IdentityFile /etc/ssh/github.pub
      IdentitiesOnly yes
  '';
}
