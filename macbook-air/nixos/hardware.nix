{ pkgs, ... }:
{
  # nixos-hardware's apple-macbook-air-6 profile already covers facetimehd
  # (gated on allowUnfree), mbpfan, and blacklisting bcma.
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
    "usbhid"
  ];
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  # Haswell (HD 5000) VA-API needs the legacy i965 driver; intel-media-driver
  # starts at Broadwell. Hardware decode is H.264 only (no VP9/AV1).
  # nixos-hardware's generic Intel GPU module installs both drivers otherwise.
  hardware.intelgpu.vaapiDriver = "intel-vaapi-driver";
  environment.sessionVariables.LIBVA_DRIVER_NAME = "i965";
  environment.systemPackages = [ pkgs.libva-utils ];

  hardware.bluetooth.enable = true;

  services.thermald.enable = true;
  services.tlp.enable = true;
  # Conflicts with TLP; some desktop modules turn it on by default.
  services.power-profiles-daemon.enable = false;
}
