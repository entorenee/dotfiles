{config, ...}: let
  binPath = "${config.home.homeDirectory}/dotfiles/nix/modules/home/bins/bin";
in {
  home.file.".local/bin".source = config.lib.file.mkOutOfStoreSymlink binPath;
}
