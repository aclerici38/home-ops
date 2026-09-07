_: {
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
      "Wireguard" = 1451685025;
    };
  };

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
}
