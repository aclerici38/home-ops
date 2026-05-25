{
  pkgs,
  config,
  lib,
  ...
}:
{
  home.username = "anthony";
  home.homeDirectory = "/Users/anthony";
  # Apparently can't change this
  home.stateVersion = "25.11";

  # Tool versions tracked via mise where possible.
  home.packages = with pkgs; [
    _1password-cli
    deadnix
    mas
    nil
    nixd
    nixfmt
    skopeo
    statix
  ];

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.home-manager.enable = true;

  # Zed (installed via brew cask) — symlink settings.json to the repo so
  # edits via Zed's "Open settings" land in version control and apply
  # without a darwin-rebuild round-trip.
  home.file.".config/zed/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-ops/zed/settings.json";

  # Bootstrap opnix via 1Password desktop
  home.activation.bootstrapOpnixToken = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    TOKEN_FILE="$HOME/.config/opnix/token"
    if [ ! -s "$TOKEN_FILE" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$TOKEN_FILE")"
      if ${pkgs._1password-cli}/bin/op read "op://Private/OPNIX_TOKEN/credential" > "$TOKEN_FILE" 2>/dev/null; then
        chmod 600 "$TOKEN_FILE"
      else
        rm -f "$TOKEN_FILE"
        echo "warning: opnix token bootstrap failed; ensure 1Password app is unlocked and OPNIX_TOKEN exists in Private vault" >&2
      fi
    fi
  '';

  # 1Password secrets materialized at activation time (one read per `drs`).
  programs.onepassword-secrets = {
    enable = true;
    tokenFile = "${config.home.homeDirectory}/.config/opnix/token";
    secrets.secretDomain = {
      reference = "op://kubernetes/cluster-secrets/SECRET_DOMAIN";
      path = ".local/share/opnix/secret-domain";
      mode = "0600";
    };
    secrets.githubToken = {
      reference = "op://kubernetes/GITHUB_TOKEN/token";
      path = ".local/share/opnix/github-token";
      mode = "0600";
    };
  };

  programs.ssh = {
    enable = true;
    settings."*".IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
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

    shellInit = ''
      set -gx MISE_GLOBAL_CONFIG_FILE $HOME/home-ops/mise.toml
    '';

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
      set -l gh ~/.local/share/opnix/github-token
      set -gx SOPS_AGE_KEY_FILE $HOME/home-ops/age.key
      set -gx TALOSCONFIG $HOME/home-ops/talos/clusterconfig/talosconfig
      test -f $f; or return
      set -gx SECRET_DOMAIN (cat $f)
      set -gx ATUIN_SYNC_ADDRESS "https://atuin.$SECRET_DOMAIN"
      test -f $gh; and set -gx GITHUB_TOKEN (cat $gh)
    '';

    interactiveShellInit = ''
      set -gx EDITOR nvim
      set fish_greeting
      load-secrets
    '';
  };
}
