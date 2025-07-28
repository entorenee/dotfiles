{ config, ... }:
let
 nvimPath = "${config.home.homeDirectory}/dotfiles/nix/module/nvim/config";
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.zsh.initContent = ''
    vlist () {
      nvim -p $(rg -l "$1")
    }
  '';

  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink nvimPath;
}
