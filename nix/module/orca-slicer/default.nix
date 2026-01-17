{
  config,
  pkgs,
  ...
}: let
  orcaConfigPath = "${config.home.homeDirectory}/dotfiles/nix/module/orca-slicer/config";
in {
  home.packages = with pkgs; [
    orca-slicer
  ];

  xdg.configFile."OrcaSlicer/user".source = config.lib.file.mkOutOfStoreSymlink orcaConfigPath;
}
