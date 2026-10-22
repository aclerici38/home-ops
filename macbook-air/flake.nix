{
  description = "2013 MacBook Air (MacBookAir6,2) laptop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixos-hardware,
      disko,
      comin,
      ...
    }@inputs:
    {
      # nixos-rebuild switch --flake .#macbook-air
      nixosConfigurations.macbook-air = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          nixos-hardware.nixosModules.apple-macbook-air-6
          disko.nixosModules.disko
          comin.nixosModules.comin
          ./nixos/disko.nix
          ./nixos/configuration.nix
          ./nixos/hardware.nix
          ./nixos/wifi.nix
          ./nixos/desktop.nix
          ./nixos/git.nix
          ./nixos/mise.nix
          ./nixos/comin.nix
        ];
      };
    };
}
