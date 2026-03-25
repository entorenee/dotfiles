{ lib, config, pkgs, ... }: let
  karabinerPath = "${config.home.homeDirectory}/dotfiles/nix/module/karabiner/config";
in
lib.mkIf pkgs.stdenv.isDarwin {
  xdg.configFile."karabiner".source = config.lib.file.mkOutOfStoreSymlink karabinerPath;
}
