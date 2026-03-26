{
  config,
  lib,
  profile,
  ...
}: let
  keepassPath = "${config.home.homeDirectory}/dotfiles/nix/module/keepassxc/config";
  isPersonalProfile = profile == "personal";
in {
  programs.keepassxc = lib.mkIf isPersonalProfile {
    enable = true;
  };

  xdg.configFile."keepassxc" = lib.mkIf isPersonalProfile {
    source = config.lib.file.mkOutOfStoreSymlink keepassPath;
  };
}
