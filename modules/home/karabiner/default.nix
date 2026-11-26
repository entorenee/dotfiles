{
  lib,
  config,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.isDarwin {
  xdg.configFile."karabiner".source = config.lib.dotfiles.link ./config;
}
