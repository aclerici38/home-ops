{ pkgs, self, ... }:
{
  nix.package = pkgs.nix;

  nix.settings.experimental-features = "nix-command flakes";

  # Deduplicate identical files in /nix/store as they're added.
  nix.settings.auto-optimise-store = true;

  # Garbage-collect old generations weekly.
  nix.gc = {
    automatic = true;
    interval = {
      Weekday = 0;
      Hour = 3;
      Minute = 0;
    };
    options = "--delete-older-than 30d";
  };

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # System-level fish: vendor completions, etc.
  # User-level fish config (aliases, abbrs, functions) lives in home.nix.
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  users.users.anthony = {
    name = "anthony";
    home = "/Users/anthony";
    shell = pkgs.fish;
  };

  system.primaryUser = "anthony";
  system.configurationRevision = self.rev or self.dirtyRev or null;

  nixpkgs.config.allowUnfree = true;
}
