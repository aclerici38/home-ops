{ pkgs, ... }:
{
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    xkb.layout = "us";
  };
  services.displayManager.defaultSession = "xfce";
  services.xserver.displayManager.lightdm.enable = true;
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      tapping = false;
      disableWhileTyping = true;
    };
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  services.printing.enable = true;
  # mDNS discovery for network printers.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.blueman.enable = true;

  # Kill the biggest process before Firefox can freeze the whole machine.
  services.earlyoom.enable = true;

  programs.firefox = {
    enable = true;
    preferences."media.ffmpeg.vaapi.enabled" = true;
    policies.ExtensionSettings = {
      "uBlock0@raymondhill.net" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
      };
      # Makes YouTube serve H.264 (the only codec the GPU decodes) instead of VP9/AV1.
      "{9a41dee2-b924-4161-a971-7fb35c053a4a}" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/enhanced-h264ify/latest.xpi";
      };
    };
  };
  environment.systemPackages = with pkgs; [
    thunderbird
    networkmanagerapplet
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
  ];
}
