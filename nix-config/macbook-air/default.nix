{ inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-hardware.nixosModules.apple-macbook-air-6
    inputs.disko.nixosModules.disko
    inputs.comin.nixosModules.comin
    ./comin.nix
    ./configuration.nix
    ./desktop.nix
    ./disko.nix
    ./hardware.nix
    ./mise.nix
    ./wifi.nix
  ];
}
