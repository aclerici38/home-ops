{
  config,
  lib,
  pkgs,
  ...
}:
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
      naturalScrolling = false;
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

  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

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
      "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
      };
    };
  };
  # The NixOS modules (not plain packages) set up the setgid helper and polkit
  # policy that browser integration, system unlock and the CLI need.
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "anthony" ];
  };
  # Serve SSH keys and git signing from the 1Password vault
  # (Settings → Developer → SSH agent).
  home-manager.users.anthony = {
    programs.ssh.settings."*".IdentityAgent = "~/.1password/agent.sock";
    programs.git.signing.signer = lib.getExe' config.programs._1password-gui.package "op-ssh-sign";
  };

  environment.systemPackages = with pkgs; [
    thunderbird
    zed-editor
    networkmanagerapplet
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
  ];
}
