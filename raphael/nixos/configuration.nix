{ config, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "usbhid"
  ];
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  networking.hostName = "raphael";
  time.timeZone = "America/Los_Angeles";
  networking.useDHCP = true;

  users.users.anthony = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.sops.secrets.anthony-password-hash.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKqgluvCmCmTP872eVF1gSq4nUozATZPwjVT4BlnuVtM anthony"
    ];
  };
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
    AllowUsers = [ "anthony" ];
  };
  services.sshguard.enable = true;

  documentation.enable = false;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };
  boot.tmp.useTmpfs = true;
  services.fstrim.enable = true;
  services.thermald.enable = true;

  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=256M
  '';
  zramSwap.enable = true;

  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 1500;
    "vm.dirty_expire_centisecs" = 6000;
    "vm.swappiness" = 180;
  };

  virtualisation.podman = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  virtualisation.oci-containers.backend = "podman";

  # subuid/subgid source for --userns=auto
  users.users.containers = {
    isSystemUser = true;
    group = "containers";
    autoSubUidGidRange = true;
  };
  users.groups.containers = { };

  hardware.bluetooth.enable = true;
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
      8123
      22000
    ];
    allowedUDPPorts = [
      5353
      21027
      22000
    ];
  };

  system.stateVersion = "26.05";
}
