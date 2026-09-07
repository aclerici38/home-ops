_: {
  # Must equal the darwinConfigurations key: comin evaluates
  # darwinConfigurations."${networking.hostName}". Set it with
  # `scutil --set HostName office-imac` before the first activation.
  networking.hostName = "office-imac";

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  homeOps.autoDeploy.enable = true;

  homeOps.llmkube = {
    enable = true;
    models = [ "qwen3-14b-metal" ];
    memoryFraction = 0.85;
  };
}
