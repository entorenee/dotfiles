{config, ...}: let
  cspellPath = "${config.home.homeDirectory}/dotfiles/nix/module/cspell/config/";
in {
  xdg.configFile."cspell".source = config.lib.file.mkOutOfStoreSymlink cspellPath;
}
