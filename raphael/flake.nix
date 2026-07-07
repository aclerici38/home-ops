{
  description = "RV minimal nix/docker host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # k3s upgrades from unstable
    nixpkgs-k3s.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
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
      disko,
      sops-nix,
      comin,
      ...
    }@inputs:
    {
      # nixos-rebuild switch --flake .#raphael
      nixosConfigurations.raphael = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          comin.nixosModules.comin
          ./nixos/disko.nix
          ./nixos/configuration.nix
          ./nixos/containers.nix
          ./nixos/mosquitto.nix
          ./nixos/comin.nix
          ./nixos/secrets.nix
          ./nixos/k3s.nix
        ];
      };
    };
}
