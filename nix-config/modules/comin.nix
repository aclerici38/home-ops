{ config, lib, ... }:
let
  cfg = config.homeOps.autoDeploy;
in
{
  options.homeOps.autoDeploy.enable = lib.mkEnableOption ''
    comin GitOps auto-deployment.
  '';

  config = lib.mkIf cfg.enable {
    services.comin = {
      enable = true;

      # Selects the flake output darwinConfigurations."<hostname>".
      hostname = config.networking.hostName;

      repositorySubdir = "nix-config";
      remotes = [
        {
          name = "origin";
          url = "https://github.com/aclerici38/home-ops.git";
          poller.period = 90;
          branches.main.name = "macos-deploy";
        }
      ];
    };
  };
}
