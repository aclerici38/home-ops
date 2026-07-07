{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # renovate: datasource=repology depName=nix_unstable/k3s versioning=loose
  k3sMinor = "1.34";

  # "1.34" -> attribute name "k3s_1_34"
  k3sSlot = "k3s_" + lib.replaceStrings [ "." ] [ "_" ] k3sMinor;

  # Pull k3s from unstable
  k3sPkgs = inputs.nixpkgs-k3s.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  services.k3s = {
    enable = true;
    role = "server";
    package = k3sPkgs.${k3sSlot};
    # Traefik is bundled by default; this box fronts everything with Caddy.
    extraFlags = [ "--disable=traefik" ];
  };
}
