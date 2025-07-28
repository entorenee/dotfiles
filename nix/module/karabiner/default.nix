{ config, ... }:
let
  karabinerPath = "${config.home.homeDirectory}/dotfiles/nix/module/karabiner/config";
in
{
  xdg.configFile."karabiner".source = config.lib.file.mkOutOfStoreSymlink karabinerPath;
}
