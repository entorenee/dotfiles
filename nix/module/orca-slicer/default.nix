{
  config,
  lib,
  pkgs,
  profile,
  ...
}: let
  orcaConfigPath = "${config.home.homeDirectory}/dotfiles/nix/module/orca-slicer/config";
  isPersonalProfile = profile == "personal";
in {
  home.packages = lib.mkIf isPersonalProfile (with pkgs; [
    orca-slicer
  ]);

  xdg.configFile."OrcaSlicer/user" = lib.mkIf isPersonalProfile {
    source = config.lib.file.mkOutOfStoreSymlink orcaConfigPath;
  };
}
