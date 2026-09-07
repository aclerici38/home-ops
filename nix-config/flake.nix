{
  description = "My nix-darwin + home-manager config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    opnix.url = "git+https://github.com/brizzbuzz/opnix?ref=v0.9.0&rev=3df56f9794912fbecf071190faf6b114f3e2733a";
    opnix.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew/main";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    comin.url = "github:nlewo/comin";
    comin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      home-manager,
      opnix,
      nix-homebrew,
      sops-nix,
      comin,
      ...
    }:
    let
      # Every Mac gets this. Nothing here may assume a login session exists.
      base = [ ./modules/common.nix ];

      desktop = [
        ./modules/desktop.nix
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

      # Machines that serve inference to the cluster.
      inferenceNode = [
        sops-nix.darwinModules.sops
        comin.darwinModules.comin
        ./modules/secrets.nix
        ./modules/comin.nix
        ./modules/llmkube.nix
        ./modules/always-on.nix
      ];

      mkDarwin =
        modules:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs self; };
          inherit modules;
        };
    in
    {
      darwinConfigurations = {
        # $ darwin-rebuild switch --flake .#Anthonys-MacBook-Pro
        "Anthonys-MacBook-Pro" = mkDarwin (base ++ desktop ++ [ ./hosts/macbook-pro.nix ]);

        # $ darwin-rebuild switch --flake .#Anthonys-Mac-mini
        "Anthonys-Mac-mini" = mkDarwin (base ++ desktop ++ inferenceNode ++ [ ./hosts/mac-mini.nix ]);

        # Minimal llmkube install
        "office-imac" = mkDarwin (base ++ inferenceNode ++ [ ./hosts/office-imac.nix ]);
      };
    };
}
