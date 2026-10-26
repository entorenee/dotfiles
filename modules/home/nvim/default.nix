{
  config,
  pkgs,
  ...
}: let
  nvimPath = "${config.home.homeDirectory}/dotfiles/modules/home/nvim/config";
in {
  # The configured editor: LazyVim config plus the shell helpers that assume it.
  # The bare binary lives in ./package.nix, which roles/home/minimal.nix imports
  # on its own for hosts that must not fetch plugins — see the note there.
  imports = [./package.nix];

  # nvim-treesitter's `main` branch compiles every parser with this CLI and has
  # no fallback, so without it :TSUpdate and the install list in
  # config/lua/plugins/ui.lua fail.
  home.packages = [pkgs.tree-sitter];

  programs.zsh.initContent = ''
    vlist () {
      nvim -p $(rg -l "$1")
    }
  '';

  xdg.configFile."nvim".source =
    if config.my.dotfiles.mutable
    then config.lib.file.mkOutOfStoreSymlink nvimPath
    else ./config;
}
