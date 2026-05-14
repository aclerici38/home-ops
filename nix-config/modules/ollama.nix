{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.ollama ];

  # Keep the Mac mini awake so the daemon below can actually serve requests.
  # Display is left to default; only system + disk sleep are disabled.
  power.sleep.computer = "never";
  power.sleep.harddisk = "never";

  system.activationScripts.ollama.text = ''
    mkdir -p /var/lib/ollama/models
    /usr/bin/mdutil -i off /var/lib/ollama >/dev/null 2>&1 || true
    /usr/bin/tmutil addexclusion /var/lib/ollama >/dev/null 2>&1 || true
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
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q8_0";
        OLLAMA_KEEP_ALIVE = "24h";
        OLLAMA_CONTEXT_LENGTH = "8192";
      };
      StandardOutPath = "/var/log/ollama.log";
      StandardErrorPath = "/var/log/ollama.err";
      ProcessType = "Standard";
    };
  };
}
