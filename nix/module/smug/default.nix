{
  config,
  pkgs,
  ...
}: let
  smugPath = "${config.home.homeDirectory}/dotfiles/nix/module/smug/projects";
in {
  home.packages = [pkgs.smug];
  xdg.configFile."smug".source = config.lib.file.mkOutOfStoreSymlink smugPath;
}
