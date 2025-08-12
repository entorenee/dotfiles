{config, ...}: let
  binPath = "${config.home.homeDirectory}/dotfiles/nix/module/bins/bin";
in {
  xdg.configFile."${config.home.homeDirectory}/.local/bin".source = config.lib.file.mkOutOfStoreSymlink binPath;
}
