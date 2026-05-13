{
  description = "My nix-darwin + home-manager config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    opnix.url = "github:brizzbuzz/opnix";
    opnix.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      home-manager,
      opnix,
      nix-homebrew,
      ...
    }:
    let
      sharedModules = [
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.sharedModules = [ opnix.homeManagerModules.default ];
          home-manager.users.anthony = import ./home.nix;
        }
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "anthony";
            autoMigrate = true;
          };
        }
      ];
    in
    {
      darwinConfigurations = {
        # $ darwin-rebuild switch --flake .#Anthonys-Mac-mini
        "Anthonys-Mac-mini" = nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs self; };
          modules = [
            ./darwin.nix
            ./modules/ollama.nix
          ]
          ++ sharedModules;
        };

        # $ darwin-rebuild switch --flake .#Anthonys-MacBook-Pro
        "Anthonys-MacBook-Pro" = nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs self; };
          modules = [ ./darwin.nix ] ++ sharedModules;
        };
      };
    };
}
