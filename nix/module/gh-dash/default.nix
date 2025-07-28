{ config, lib, profile, ... }:
let
  isWorkProfile = profile == "work";
  workConfig = "${config.home.homeDirectory}/dotfiles/nix/module/gh-dash/config/work-config.yml";
  starterConfig = "${config.home.homeDirectory}/dotfiles/nix/module/gh-dash/config/starter-config.yml";
  configPath = if isWorkProfile then workConfig else starterConfig;
in
{
  programs.gh-dash = {
    enable = true;
  };

  xdg.configFile."gh-dash/config.yml".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink configPath);
}
