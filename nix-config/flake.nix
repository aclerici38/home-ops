{
  description = "My nix-darwin + home-manager config";

  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixpkgs-unstable&rev=48d91f2c0ce7b9e589f967d4f685153dd765dcdd";

    nix-darwin.url = "git+https://github.com/nix-darwin/nix-darwin?ref=master&rev=8c62fba0854ba15c8917aed18894dbccb48a3777";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "git+https://github.com/nix-community/home-manager?ref=master&rev=6a0bbd6b4720da1c9ce7ebf35ff5c41a82db367a";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    opnix.url = "github:brizzbuzz/opnix/v0.9.0";
    opnix.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "git+https://github.com/zhaofengli/nix-homebrew?ref=main&rev=7d0038b5bb60568ec41f5f4ef5067cd221ca7c0d";
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
