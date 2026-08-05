{
  config,
  pkgs,
  ...
}: let
  smugPath = "${config.home.homeDirectory}/dotfiles/nix/modules/home/smug/projects";
in {
  home.packages = [pkgs.smug];
  xdg.configFile."smug".source = config.lib.file.mkOutOfStoreSymlink smugPath;
}
