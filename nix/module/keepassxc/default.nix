{config, ...}: let
  keepassPath = "${config.home.homeDirectory}/dotfiles/nix/module/keepassxc/config";
in {
  programs.keepassxc = {
    enable = true;
  };

  xdg.configFile."keepassxc".source = config.lib.file.mkOutOfStoreSymlink keepassPath;
}
