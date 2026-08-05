{ config, pkgs, ... }:
let
  nvimPath = "${config.home.homeDirectory}/dotfiles/nix/modules/home/nvim/config";
in
{
  home.packages = [ pkgs.neovim ];
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    MANPAGER = "nvim -c 'Man!' -o -";
  };

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
