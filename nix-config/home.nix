# home-manager config shared by every host. Platform-specific bits live next to
# the host config: home-darwin.nix and macbook-air/desktop.nix.
{
  pkgs,
  config,
  ...
}:
let
  # Held in 1Password; GitHub has it registered for both auth and signing.
  githubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKqgluvCmCmTP872eVF1gSq4nUozATZPwjVT4BlnuVtM";
  rebuild = if pkgs.stdenv.hostPlatform.isDarwin then "darwin-rebuild" else "nixos-rebuild";
in
{
  # Apparently can't change this
  home.stateVersion = "25.11";

  # Tool versions tracked via mise where possible.
  home.packages = with pkgs; [
    deadnix
    nil
    nixd
    nixfmt
    skopeo
    statix
  ];

  # Only bootstraps: fish activates the aqua:jdx/mise build pinned in mise.lock.
  programs.mise = {
    enable = true;
    enableFishIntegration = false;
  };

  programs.home-manager.enable = true;

  # Symlink Zed's settings.json to the repo so edits via Zed's "Open settings"
  # land in version control and apply without a rebuild round-trip.
  home.file.".config/zed/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-ops/zed/settings.json";

  # The 1Password agent socket is set per platform. For GitHub, only offer its
  # key and refuse unknown host keys instead of prompting.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."github.com" = {
      IdentityFile = "~/.ssh/github.pub";
      IdentitiesOnly = true;
      StrictHostKeyChecking = "yes";
    };
  };
  home.file.".ssh/github.pub".text = "${githubKey}\n";

  # The op-ssh-sign signer is set per platform.
  programs.git = {
    enable = true;
    signing = {
      format = "ssh";
      key = "key::${githubKey}";
      signByDefault = true;
      # Lets `git log --show-signature` verify our own signatures locally.
      allowedSigners = "anthony@clerici.me ${githubKey}";
    };
    settings = {
      user = {
        email = "anthony@clerici.me";
        name = "aclerici38";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      # Reject corrupt or malformed objects on every fetch, clone and push.
      transfer.fsckObjects = true;
      # Pushes always go over SSH; https clones (and comin) are left alone.
      url."git@github.com:".pushInsteadOf = "https://github.com/";
    };
  };

  programs.direnv.enable = true;

  programs.fish = {
    enable = true;

    # The repo's .mise.toml is the global config, so every machine runs the
    # versions pinned in mise.lock.
    shellInit = ''
      set -gx MISE_GLOBAL_CONFIG_FILE $HOME/home-ops/.mise.toml
    '';

    shellAliases = {
      k = "kubectl";
      ll = "ls -lah";
      t = "talosctl";
    };

    shellAbbrs = {
      drs = "sudo ${rebuild} switch --flake ~/home-ops/nix-config";
    };

    interactiveShellInit = ''
      set fish_greeting
      set -l _aqua_mise_dir $HOME/.local/share/mise/installs/aqua-jdx-mise
      set -l _ver
      test -d $_aqua_mise_dir; and set _ver (command ls $_aqua_mise_dir | sort -V | tail -1)
      if test -n "$_ver"; and test -x $_aqua_mise_dir/$_ver/mise/bin/mise
        $_aqua_mise_dir/$_ver/mise/bin/mise activate fish | source
      else
        mise activate fish | source
      end
      type -q atuin; and atuin init fish | source
    '';
  };
}
