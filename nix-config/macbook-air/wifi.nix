{ config, lib, ... }:
let
  kp = config.boot.kernelPackages;
  modDir = "lib/modules/${kp.kernel.modDirVersion}";
in
{
  # BCM4360 Wi-Fi: only Broadcom's proprietary wl driver supports it, and the
  # in-tree drivers must stay out of its way. Shared with the installer ISO.
  boot.kernelModules = [ "wl" ];
  boot.extraModulePackages = [
    # Module aggregation now needs each external module's wl.ko.cer, which only
    # kbuild's modules_install writes. Backport of nixpkgs#576651; turns itself
    # off once that lands.
    (kp.broadcom_sta.overrideAttrs (
      old:
      lib.optionalAttrs (!lib.hasInfix "modules_install" old.installPhase) {
        makeFlags = kp.kernelModuleMakeFlags ++ old.makeFlags;
        installPhase = ''
          runHook preInstall
          local flagsArray=()
          concatTo flagsArray makeFlags makeFlagsArray
          KBUILD_NOPEDANTIC=1 make -C ${kp.kernel.dev}/${modDir}/build \
            M="$PWD" "''${flagsArray[@]}" \
            INSTALL_MOD_PATH="$out" INSTALL_MOD_DIR=kernel/net/wireless DEPMOD=true \
            modules_install
          install -Dm644 lib/LICENSE.txt -t "$out/share/doc/broadcom-sta"
          runHook postInstall
        '';
      }
    ))
  ];
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
}
