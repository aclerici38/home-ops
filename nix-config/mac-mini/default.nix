{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  agent = pkgs.callPackage ./llmkube-metal-agent.nix { };
  user = "_llmkube";
  home = "/var/lib/llmkube";
in
{
  imports = [ inputs.comin.darwinModules.comin ];

  users = {
    knownUsers = [ user ];
    knownGroups = [ user ];
    users.${user} = {
      uid = 540;
      gid = 540;
      inherit home;
      shell = "/usr/bin/false";
      description = "LLMKube metal-agent";
    };
    groups.${user} = {
      gid = 540;
      description = "LLMKube metal-agent";
    };
  };

  # createhomedir can't handle a home behind the /var symlink (ELOOP)
  system.activationScripts.postActivation.text = ''
    mkdir -p ${home}
    chown -R ${user}:${user} ${home}
    chmod 700 ${home}
  '';

  # A daemon, not the LaunchAgent `llmkube metal join` installs: agents wait for
  # a GUI login, and lose local network access with every new binary (TN3179).
  launchd.daemons.llmkube-metal-agent = {
    # Same arguments as join, which writes the kubeconfig and token into $HOME
    command = lib.escapeShellArgs [
      (lib.getExe agent)
      "--kubeconfig"
      "${home}/Library/Application Support/llmkube/metal-agent/kubeconfig"
      "--namespace"
      "llmkube"
      "--metal-node"
      "mac-mini"
      "--renew-service-account-token"
      "--log-level"
      "info"
      "--llama-server"
      (lib.getExe' pkgs.llama-cpp "llama-server")
      # Auto-detection prefers VPN addresses; keep in sync with the
      # llmkube-metal CiliumNetworkPolicy
      "--host-ip"
      "10.0.40.140"
    ];
    serviceConfig = {
      Label = "com.llmkube.metal-agent";
      UserName = user;
      GroupName = user;
      EnvironmentVariables.HOME = home;
      WorkingDirectory = home;
      RunAtLoad = true;
      # Engines outlive the agent, and the next one adopts them
      KeepAlive = true;
      ThrottleInterval = 30;
      ProcessType = "Interactive";
      StandardOutPath = "${home}/metal-agent.log";
      StandardErrorPath = "${home}/metal-agent.log";
    };
  };

  services.comin = {
    enable = true;
    hostname = "Anthonys-Mac-mini";
    repositorySubdir = "nix-config";
    remotes = [
      {
        name = "origin";
        url = "https://github.com/aclerici38/home-ops.git";
        poller.period = 3600;
        branches.main.name = "main";
      }
    ];
  };

  # comin activates unattended, and a cask upgrade can stop to ask for sudo
  homebrew.onActivation.upgrade = lib.mkForce false;

  power = {
    sleep.computer = "never";
    sleep.display = 10;
    restartAfterPowerFailure = true;
  };

  # FileVault holds every cold boot at the unlock screen, before launchd starts
  # anything. macOS 26 accepts the password over ssh there.
  services.openssh.enable = true;

  # Update by hand with `fdesetup authrestart`, which skips that screen once
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
}
