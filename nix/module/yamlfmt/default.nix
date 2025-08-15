{config, ...}: let
  yamlfmtPath = "${config.home.homeDirectory}/dotfiles/nix/module/yamlfmt/config/.yamlfmt";
in {
  xdg.configFile.".yamlfmt".source = config.lib.file.mkOutOfStoreSymlink yamlfmtPath;
}
