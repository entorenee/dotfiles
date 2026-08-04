{ config, ... }:
let
  lazygitPath = "${config.home.homeDirectory}/dotfiles/nix/modules/lazygit/config";
in
{
  programs.lazygit = {
    enable = true;
  };

  xdg.configFile."lazygit".source = config.lib.file.mkOutOfStoreSymlink lazygitPath;
}
