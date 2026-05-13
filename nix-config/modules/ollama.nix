{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.ollama ];

  system.activationScripts.ollama.text = ''
    mkdir -p /var/lib/ollama/models
  '';

  launchd.daemons.ollama = {
    serviceConfig = {
      Label = "com.anthony.ollama";
      ProgramArguments = [
        "${pkgs.ollama}/bin/ollama"
        "serve"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      EnvironmentVariables = {
        OLLAMA_HOST = "0.0.0.0:11434";
        OLLAMA_MODELS = "/var/lib/ollama/models";
        HOME = "/var/lib/ollama";
      };
      StandardOutPath = "/var/log/ollama.log";
      StandardErrorPath = "/var/log/ollama.err";
      ProcessType = "Background";
    };
  };
}
