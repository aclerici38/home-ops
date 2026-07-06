{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "usbhid" ];
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  networking.hostName = "raphael";
  time.timeZone = "America/Los_Angeles";
  networking.useDHCP = true;

  users.users.anthony = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA...replace-me... you@laptop" ];
  };
  services.openssh.enable = true;
  services.openssh.settings = { PasswordAuthentication = false; PermitRootLogin = "no"; };
  security.sudo.wheelNeedsPassword = false;

  # Flakes on by default, and keep an appliance's disk from filling silently.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };
  boot.tmp.cleanOnBoot = true;
  services.fstrim.enable = true; # NVMe TRIM

  virtualisation.podman = {
    enable = true;
    autoPrune = { enable = true; dates = "weekly"; };
  };
  virtualisation.oci-containers.backend = "podman";

  hardware.bluetooth.enable = true;
  hardware.graphics = { enable = true; extraPackages = with pkgs; [ intel-media-driver vpl-gpu-rt ]; };
  networking.firewall.enable = false;

  system.stateVersion = "26.05";
}
