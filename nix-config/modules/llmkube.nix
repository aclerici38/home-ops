{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homeOps.llmkube;
in
{
  options.homeOps.llmkube = {
    enable = lib.mkEnableOption "the LLMKube Metal agent";

    hostIP = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "10.38.50.40";
      description = ''
        IP this Mac registers in the EndpointSlice it writes back to the
        cluster, i.e. the address cluster pods dial to reach llama-server.
        null lets the agent auto-detect. Pin it if the Mac ever grows a second
        routable interface (a VPN utun, a USB NIC): auto-detection picks one
        heuristically, and picking wrong black-holes inference silently — the
        EndpointSlice looks healthy while nothing can reach it.
      '';
    };

    models = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [ "qwen3-30b-metal" ];
      description = ''
        InferenceService names this agent may claim. With more than one Mac on
        the cluster this is load-bearing: an empty allowlist means "claim every
        metal InferenceService in the namespace", so two agents would race for
        the same models and fight over the EndpointSlice.
      '';
    };

    namespace = lib.mkOption {
      type = lib.types.str;
      default = "llmkube";
      description = "Namespace holding the InferenceService resources to watch.";
    };

    memoryFraction = lib.mkOption {
      type = lib.types.float;
      default = 0.0;
      description = ''
        Fraction of system RAM the agent may budget for models. 0 auto-detects
        from total RAM (67% at 16-36 GB, 75% at 48 GB and above). Raise it on a
        machine that does nothing but serve; models over budget are refused
        with an InsufficientMemory status rather than started and swapped.
      '';
    };

    kubeconfig = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the kubeconfig the agent authenticates with, normally a
        sops-nix secret path. Its ServiceAccount is scoped per-Mac so either
        can be revoked without touching the other.
      '';
    };

    modelStore = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/llmkube/models";
      description = ''
        Where downloaded GGUFs land. Not upstream's /tmp default: these are
        multi-GB files and macOS prunes /tmp, which would re-download the whole
        model set after every reboot.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.models != [ ];
        message = ''
          homeOps.llmkube.models is empty, which the agent reads as "claim every
          metal InferenceService in ${cfg.namespace}". List this Mac's models
          explicitly so it cannot race the other agent.
        '';
      }
    ];

    nixpkgs.overlays = [
      (_final: prev: {
        llmkube-metal-agent = prev.callPackage ../pkgs/llmkube-metal-agent.nix { };
      })
    ];

    # A LaunchDaemon, not the LaunchAgent upstream ships: agents live in
    # ~/Library/LaunchAgents and only run while that user is logged in, but
    # these Macs sit logged out, and may be logged into a different user.
    # nix-darwin wraps `script` in `wait4path /nix/store`, which also covers the
    # boot race where launchd starts a daemon before the Nix volume is mounted.
    launchd.daemons.llmkube-metal-agent = {
      script =
        let
          args = [
            "--namespace"
            cfg.namespace
            "--kubeconfig"
            "${cfg.kubeconfig}"
            "--llama-server"
            (lib.getExe' pkgs.llama-cpp "llama-server")
            "--model-store"
            "${cfg.modelStore}"
            "--inference-service-allowlist"
            (lib.concatStringsSep "," cfg.models)
            "--port"
            "9090"
            "--log-level"
            "info"
          ]
          ++ lib.optionals (cfg.hostIP != null) [
            "--host-ip"
            cfg.hostIP
          ]
          # 0 means "auto-detect from total RAM" upstream, which it only does
          # when the flag is absent entirely.
          ++ lib.optionals (cfg.memoryFraction != 0.0) [
            "--memory-fraction"
            (toString cfg.memoryFraction)
          ];
        in
        ''
          install -d -m 0755 ${cfg.modelStore}
          exec ${lib.getExe pkgs.llmkube-metal-agent} ${lib.escapeShellArgs args}
        '';

      serviceConfig = {
        Label = "com.llmkube.metal-agent";
        RunAtLoad = true;
        # Unconditional: the agent exits on a lost watch and expects a
        # supervisor to bring it back (see --max-watch-failures). Throttled so a
        # missing kubeconfig on a fresh box backs off instead of spinning.
        KeepAlive = true;
        ThrottleInterval = 30;
        StandardOutPath = "/var/log/llmkube-metal-agent.log";
        StandardErrorPath = "/var/log/llmkube-metal-agent.log";
      };
    };
  };
}
