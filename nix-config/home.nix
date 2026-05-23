{ pkgs, config, ... }:
{
  home.username = "anthony";
  home.homeDirectory = "/Users/anthony";
  # Apparently can't change this
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    _1password-cli
    age
    cilium-cli
    claude-code
    crane
    envsubst
    ffmpeg
    fluxcd
    gh
    go
    helm-docs
    helmfile
    jq
    k9s
    kind
    kubebuilder
    kubectl
    kubectl-cnpg
    kubernetes-helm
    kustomize
    mas
    minio-client
    minijinja
    mise
    neovim
    nil
    nixd
    nixfmt
    sops
    skopeo
    yq
    talhelper
    talosctl
    uv
    zizmor
  ];

  programs.home-manager.enable = true;

  # 1Password secrets materialized at activation time (one read per `drs`).
  # Token at ~/.config/opnix/token; set via `opnix token set`.
  programs.onepassword-secrets = {
    enable = true;
    tokenFile = "${config.home.homeDirectory}/.config/opnix/token";
    secrets.secretDomain = {
      reference = "op://kubernetes/cluster-secrets/SECRET_DOMAIN";
      path = ".local/share/opnix/secret-domain";
      mode = "0600";
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      extraOptions.IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        email = "anthony@clerici.me";
        name = "aclerici38";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      gpg.format = "ssh";
      commit.gpgsign = true;
      "gpg.ssh".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      user.signingkey = "key::ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKqgluvCmCmTP872eVF1gSq4nUozATZPwjVT4BlnuVtM";
    };
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;

  };

  programs.direnv.enable = true;

  programs.fish = {
    enable = true;

    shellAliases = {
      k = "kubectl";
      ll = "ls -lah";
      t = "talosctl";
    };

    shellAbbrs = {
      drs = "sudo darwin-rebuild switch --flake ~/home-ops/nix-config";
    };

    functions.load-secrets = ''
      set -l f ~/.local/share/opnix/secret-domain
      set -gx SOPS_AGE_KEY_FILE $HOME/home-ops/age.key
      set -gx TALOSCONFIG $HOME/home-ops/talos/clusterconfig/talosconfig
      test -f $f; or return
      set -gx SECRET_DOMAIN (cat $f)
      set -gx ATUIN_SYNC_ADDRESS "https://atuin.$SECRET_DOMAIN"
    '';

    interactiveShellInit = ''
      set -gx EDITOR nvim
      set fish_greeting
      load-secrets
    '';
  };
}
