{ config, ... }:
let
  ghosttyPath = "${config.home.homeDirectory}/dotfiles/modules/home/ghostty/config";
in
{
  xdg.configFile."ghostty".source = config.lib.file.mkOutOfStoreSymlink ghosttyPath;
}
