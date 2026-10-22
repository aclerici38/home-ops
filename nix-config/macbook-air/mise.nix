{ pkgs, ... }:
{
  # mise itself and its fish activation come from home.nix. gcc/make for things
  # that compile on the fly: nvim-treesitter parsers, Python/npm packages with
  # native extensions, cgo.
  environment.systemPackages = with pkgs; [
    gcc
    gnumake
  ];

  # mise downloads generic glibc binaries (node, python, neovim, uv, ...),
  # which can't find a dynamic loader on NixOS without this.
  programs.nix-ld.enable = true;

  # mise defaults all_compile to true on NixOS, building node and python from
  # source even though mise.lock pins prebuilt downloads. nix-ld makes those run.
  environment.variables.MISE_ALL_COMPILE = "false";
}
