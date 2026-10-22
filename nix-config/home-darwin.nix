# macOS-only home-manager config, layered on home.nix by darwin.nix.
{
  pkgs,
  config,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    _1password-cli
    mas
  ];

  programs.ssh.settings."*".IdentityAgent =
    "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
  programs.git.signing.signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";

  # Bootstrap opnix via 1Password desktop
  home.activation.bootstrapOpnixToken = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    TOKEN_FILE="$HOME/.config/opnix/token"
    if [ ! -s "$TOKEN_FILE" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$TOKEN_FILE")"
      if ${pkgs._1password-cli}/bin/op read "op://Private/OPNIX_TOKEN/credential" > "$TOKEN_FILE" 2>/dev/null; then
        chmod 600 "$TOKEN_FILE"
      else
        rm -f "$TOKEN_FILE"
        echo "warning: opnix token bootstrap failed; ensure 1Password app is unlocked and OPNIX_TOKEN exists in Private vault" >&2
      fi
    fi
  '';

  # 1Password secrets materialized at activation time (one read per `drs`).
  programs.onepassword-secrets = {
    enable = true;
    tokenFile = "${config.home.homeDirectory}/.config/opnix/token";
    secrets.githubToken = {
      reference = "op://kubernetes/GITHUB_TOKEN/token";
      path = ".local/share/opnix/github-token";
      mode = "0600";
    };
  };

  programs.fish = {
    functions.load-secrets = ''
      set -l gh ~/.local/share/opnix/github-token
      test -f $gh; and set -gx GITHUB_TOKEN (cat $gh)
    '';
    interactiveShellInit = lib.mkBefore "load-secrets";
  };
}
