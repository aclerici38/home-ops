{ config, lib, ... }:
{
  # BCM4360 Wi-Fi: only Broadcom's proprietary wl driver supports it, and the
  # in-tree drivers must stay out of its way. Shared with the installer ISO.
  boot.kernelModules = [ "wl" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.blacklistedKernelModules = [
    "b43"
    "bcma"
    "ssb"
    "brcmfmac"
    "brcmsmac"
  ];

  # broadcom_sta is unmaintained and carries CVE-2019-9501/9502 (heap overflows
  # reachable from crafted Wi-Fi frames). Accepted: this laptop only ever joins
  # the home network. A predicate instead of permittedInsecurePackages because
  # that pins the exact version string, which changes on every kernel bump.
  nixpkgs.config.allowInsecurePredicate =
    pkg: lib.hasPrefix "broadcom-sta" (pkg.pname or pkg.name or "");
  nixpkgs.config.allowUnfree = true;
}
