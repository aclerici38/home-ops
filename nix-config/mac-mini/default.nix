{
  pkgs,
  config,
  self,
  ...
}:
let
  agent = self.packages.${pkgs.stdenv.hostPlatform.system}.llmkube-metal-agent;
  home = config.users.users.anthony.home;
  secretDir = ".local/share/opnix/llmkube-metal-agent";

  kubeconfig = pkgs.writeText "llmkube-metal-agent-kubeconfig.json" (
    builtins.toJSON {
      apiVersion = "v1";
      kind = "Config";
      clusters = [
        {
          name = "dormammu";
          cluster = {
            server = "https://10.0.30.250:6443";
            certificate-authority = "${home}/${secretDir}/ca.crt";
          };
        }
      ];
      users = [
        {
          name = "llmkube-metal-agent";
          user.tokenFile = "${home}/${secretDir}/token";
        }
      ];
      contexts = [
        {
          name = "llmkube-metal-agent";
          context = {
            cluster = "dormammu";
            user = "llmkube-metal-agent";
            namespace = "llmkube";
          };
        }
      ];
      current-context = "llmkube-metal-agent";
    }
  );

  # --host-ip lands verbatim in an IPv4 EndpointSlice, so resolve the name here
  start = pkgs.writeShellScript "llmkube-metal-agent" ''
    ip=$(/usr/bin/dscacheutil -q host -a name mac-mini.cottage.internal | /usr/bin/awk '/^ip_address:/ { print $2; exit }')
    [ -n "$ip" ] || { echo "mac-mini.cottage.internal did not resolve" >&2; exit 1; }
    exec ${agent}/bin/llmkube-metal-agent \
      --kubeconfig ${kubeconfig} \
      --namespace llmkube \
      --llama-server ${pkgs.llama-cpp}/bin/llama-server \
      --host-ip "$ip"
  '';
in
{
  home-manager.users.anthony.programs.onepassword-secrets.secrets = {
    llmkubeMetalAgentToken = {
      reference = "op://kubernetes/llmkube-metal-agent/token";
      path = "${secretDir}/token";
      mode = "0600";
    };
    llmkubeMetalAgentCA = {
      reference = "op://kubernetes/llmkube-metal-agent/ca";
      path = "${secretDir}/ca.crt";
      mode = "0600";
    };
  };

  # Daemon rather than upstream's LaunchAgent: runs without a login session
  launchd.daemons.llmkube-metal-agent.serviceConfig = {
    Label = "com.llmkube.metal-agent";
    UserName = "anthony";
    GroupName = "staff";
    ProgramArguments = [ "${start}" ];
    EnvironmentVariables.HOME = home;
    WorkingDirectory = home;
    RunAtLoad = true;
    KeepAlive.SuccessfulExit = false;
    ThrottleInterval = 30;
    ProcessType = "Interactive";
    StandardOutPath = "${home}/Library/Logs/llmkube-metal-agent.log";
    StandardErrorPath = "${home}/Library/Logs/llmkube-metal-agent.log";
  };

  power = {
    sleep.computer = "never";
    sleep.display = 10;
    restartAfterPowerFailure = true;
  };

  # FileVault holds a reboot at the unlock screen; update by hand with `fdesetup authrestart`
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
}
