{
  description = "My nix-darwin + home-manager config";

  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixpkgs-unstable&rev=d233902339c02a9c334e7e593de68855ad26c4cb";

    nix-darwin.url = "git+https://github.com/nix-darwin/nix-darwin?ref=master&rev=56c666e108467d87d13508936aade6d567f2a501";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "git+https://github.com/nix-community/home-manager?ref=master&rev=866412a19866b4a8e32d2306a118040afa2b840c";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    opnix.url = "github:brizzbuzz/opnix/v0.9.0";
    opnix.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "git+https://github.com/zhaofengli/nix-homebrew?ref=main&rev=b3a87b4793205cc111f3c61e25e018ffac3b8039";
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
