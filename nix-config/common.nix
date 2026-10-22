# System config shared by nix-darwin and NixOS hosts.
{ pkgs, self, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.anthony = ./home.nix;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Schedules are per-platform (launchd intervals vs systemd calendars).
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
  # Scheduled dedup instead of auto-optimise-store, which can corrupt the store
  # on darwin.
  nix.optimise.automatic = true;

  nixpkgs.config.allowUnfree = true;

  programs.fish.enable = true;
  users.users.anthony.shell = pkgs.fish;

  # Pin GitHub's host key (api.github.com/meta); home.nix refuses anything else.
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  system.configurationRevision = self.rev or self.dirtyRev or null;
}
