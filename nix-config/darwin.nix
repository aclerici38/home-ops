{ pkgs, self, ... }:
{
  homebrew = {
    enable = true;
    onActivation.autoUpdate = false;
    onActivation.upgrade = true;
    onActivation.cleanup = "zap";
    brews = [
    ];

    casks = [
      "1password"
      "android-platform-tools"
      "balenaetcher"
      "discord"
      "docker-desktop"
      "ghostty"
      "istat-menus"
      "opencloud"
      "protonvpn"
      "spotify"
      "wireshark-app"
      "ultimaker-cura"
      "utm"
      "vlc"
      "wireguard"
      "zen"
      "zed"
      "zoom"
    ];
    masApps = {
      "Discovery" = 1381004916;
      "Magnet" = 441258766;
    };
  };

  nix.package = pkgs.nix;

  nix.settings.experimental-features = "nix-command flakes";

  # Deduplicate identical files in /nix/store as they're added.
  nix.settings.auto-optimise-store = true;

  # Garbage-collect old generations weekly.
  nix.gc = {
    automatic = true;
    interval = {
      Weekday = 0;
      Hour = 3;
      Minute = 0;
    };
    options = "--delete-older-than 30d";
  };

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # macOS stuffs
  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
    };
    finder = {
      AppleShowAllFiles = true;
      FXDefaultSearchScope = "SCcf";
      FXPreferredViewStyle = "Nlsv"; # default new windows to list
      ShowPathbar = true;
      ShowStatusBar = true;
    };
    dock = {
      autohide = false;
      show-recents = false;
    };
  };

  # System-level fish: vendor completions, etc.
  # User-level fish config (aliases, abbrs, functions) lives in home.nix.
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  users.users.anthony = {
    name = "anthony";
    home = "/Users/anthony";
    shell = pkgs.fish;
  };

  system.primaryUser = "anthony";
  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;
}
