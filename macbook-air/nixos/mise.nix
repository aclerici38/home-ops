{ pkgs, ... }:
{
  # Same setup as nix-config/home.nix: the repo's .mise.toml is the global
  # config, so every machine runs the versions pinned in mise.lock. nixpkgs'
  # mise only bootstraps; after `mise install` the aqua:jdx/mise build pinned
  # there takes over. gcc/make for things that compile on the fly:
  # nvim-treesitter parsers, Python/npm packages with native extensions, cgo.
  environment.systemPackages = with pkgs; [
    mise
    gcc
    gnumake
  ];

  # mise downloads generic glibc binaries (node, python, neovim, uv, ...),
  # which can't find a dynamic loader on NixOS without this.
  programs.nix-ld.enable = true;

  # mise defaults all_compile to true on NixOS, building node and python from
  # source even though mise.lock pins prebuilt downloads. nix-ld makes those run.
  environment.variables.MISE_ALL_COMPILE = "false";

  programs.fish = {
    shellInit = ''
      set -gx MISE_GLOBAL_CONFIG_FILE $HOME/home-ops/.mise.toml
    '';
    interactiveShellInit = ''
      set -l _aqua_mise_dir $HOME/.local/share/mise/installs/aqua-jdx-mise
      set -l _ver
      test -d $_aqua_mise_dir; and set _ver (command ls $_aqua_mise_dir | sort -V | tail -1)
      if test -n "$_ver"; and test -x $_aqua_mise_dir/$_ver/mise/bin/mise
        $_aqua_mise_dir/$_ver/mise/bin/mise activate fish | source
      else
        ${pkgs.mise}/bin/mise activate fish | source
      end
    '';
  };
}
