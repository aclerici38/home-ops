{ inputs, pkgs, ... }:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  home-manager.users.anthony.imports = [
    inputs.opnix.homeManagerModules.default
    ./home-darwin.nix
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "anthony";
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    onActivation.autoUpdate = false;
    onActivation.upgrade = true;
    onActivation.cleanup = "zap";
    brews = [
      "ffmpeg"
    ];

    casks = [
      "1password"
      "android-platform-tools"
      "balenaetcher"
      "discord"
      "docker-desktop"
      "ghostty"
      "opencloud"
      "protonvpn"
      "spotify"
      "whatcable"
      "wireshark-app"
      "ultimaker-cura"
      "utm"
      "vlc"
      "zen"
      "zed"
      "zoom"
    ];
    masApps = {
      "Discovery" = 1381004916;
      "Magnet" = 441258766;
      "Moonfin" = 6761283970;
      "Wireguard" = 1451685025;
    };
  };

  nix.package = pkgs.nix;

  # Garbage-collect old generations weekly.
  nix.gc.interval = {
    Weekday = 0;
    Hour = 3;
    Minute = 0;
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

  # Lets chsh/Users & Groups accept fish as a login shell.
  environment.shells = [ pkgs.fish ];

  users.users.anthony.home = "/Users/anthony";

  system.primaryUser = "anthony";
  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";
}
