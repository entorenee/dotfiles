{config, ...}: let
  worktrunkConfigPath = "${config.home.homeDirectory}/dotfiles/nix/module/worktrunk/config";
in {
  programs.worktrunk = {
    enable = true;
    enableZshIntegration = true;
  };

  xdg.configFile."worktrunk".source = config.lib.file.mkOutOfStoreSymlink worktrunkConfigPath;
}
