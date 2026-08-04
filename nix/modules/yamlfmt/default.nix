{config, ...}: let
  yamlfmtPath = "${config.home.homeDirectory}/dotfiles/nix/modules/yamlfmt/config/.yamlfmt";
in {
  xdg.configFile.".yamlfmt".source = config.lib.file.mkOutOfStoreSymlink yamlfmtPath;
}
