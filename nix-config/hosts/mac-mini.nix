_: {
  # Must equal the darwinConfigurations key: comin evaluates
  # darwinConfigurations."${networking.hostName}".
  networking.hostName = "Anthonys-Mac-mini";

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  homeOps.autoDeploy.enable = true;

  homeOps.llmkube = {
    enable = true;
    models = [ "qwen3-8b-metal" ];
  };
}
