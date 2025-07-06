{ config, ... }:
let
  gitConfigPath = "${config.home.homeDirectory}/dotfiles/nix/module/git/config";
in
{
  programs.git = {
    enable = true;
  };

  # TODO: This may be able to be cleaned up with Nix Darwin
  xdg.configFile."git/config".source = config.lib.file.mkOutOfStoreSymlink "${gitConfigPath}/config";
  xdg.configFile."git/config-personal".source = config.lib.file.mkOutOfStoreSymlink "${gitConfigPath}/config-personal";
  xdg.configFile."git/config-work".source = config.lib.file.mkOutOfStoreSymlink "${gitConfigPath}/config-work";
  xdg.configFile."git/ignore".source = config.lib.file.mkOutOfStoreSymlink "${gitConfigPath}/ignore";
}
