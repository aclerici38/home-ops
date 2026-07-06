{
  description = "RV minimal nix/docker host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
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

  outputs = { self, nixpkgs, disko, sops-nix, comin, ... }: {
    # nixos-rebuild switch --flake .#raphael
    nixosConfigurations.raphael = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        comin.nixosModules.comin
        ./nixos/disko.nix
        ./nixos/configuration.nix
        ./nixos/containers.nix
        ./nixos/comin.nix
        ./nixos/proxy.nix
        ./nixos/secrets.nix
      ];
    };
  };
}
