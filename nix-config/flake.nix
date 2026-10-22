{
  description = "My nix-darwin, NixOS and home-manager configs";

  inputs = {
    # Macs: nixpkgs-unstable only advances once darwin builds are cached.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # NixOS: nixos-unstable additionally waits on the NixOS boot/module tests.
    nixpkgs-nixos.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # useGlobalPkgs: each host builds home-manager against its own nixpkgs.
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    opnix.url = "git+https://github.com/brizzbuzz/opnix?ref=main&rev=0ea3a9e6a94fdd0c444aa7729b98e568a0588222";
    opnix.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew/main";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs-nixos";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs-nixos";

    comin.url = "github:nlewo/comin";
    comin.inputs.nixpkgs.follows = "nixpkgs-nixos";
  };

  outputs =
    inputs@{
      self,
      nixpkgs-nixos,
      nix-darwin,
      ...
    }:
    let
      specialArgs = { inherit inputs self; };
      mac = nix-darwin.lib.darwinSystem {
        inherit specialArgs;
        modules = [
          ./common.nix
          ./darwin.nix
        ];
      };
    in
    {
      # $ darwin-rebuild switch --flake .
      darwinConfigurations = {
        "Anthonys-Mac-mini" = mac;
        "Anthonys-MacBook-Pro" = mac;
      };

      # $ nixos-rebuild switch --flake .  (comin deploys main automatically)
      nixosConfigurations.macbook-air = nixpkgs-nixos.lib.nixosSystem {
        inherit specialArgs;
        modules = [
          ./common.nix
          ./macbook-air
        ];
      };
    };
}
