{
  config,
  lib,
  pkgs,
  ...
}: let
  ghDashConfig = "${config.home.homeDirectory}/dotfiles/nix/users/personal/gh-dash.yml";
in {
  # Personal identity, home-manager side. Imported by every machine that is
  # "me personally" — the personal Mac and the Linux desktop — alongside a role.
  #
  # Modules listed here rather than in a role are ones only this persona wants at
  # all; a role would have to gate them back off.
  imports = [
    ./claude.nix

    ../../modules/home/keepassxc
    ../../modules/home/orca-slicer
  ];

  home.packages = with pkgs; [
    go
    hugo
  ];

  # No ssh block: the personal Yubikey is the module's default identity.

  xdg.configFile."gh-dash/config.yml".source =
    lib.mkForce (config.lib.file.mkOutOfStoreSymlink ghDashConfig);

  services.syncthing.enable = true;
}
