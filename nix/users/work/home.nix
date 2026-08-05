{
  config,
  lib,
  pkgs,
  ...
}: let
  personalYubikeyIdentity = "${config.home.homeDirectory}/.ssh/id_rsa_yubikey_personal.pub";
  workYubikeyIdentity = "${config.home.homeDirectory}/.ssh/id_rsa_yubikey_work.pub";
  ghDashConfig = "${config.home.homeDirectory}/dotfiles/nix/users/work/gh-dash.yml";
in {
  # Work identity, home-manager side. Imported by the work Mac alongside a role.
  imports = [
    ./claude.nix
  ];

  home.packages = with pkgs; [
    cocoapods
    doctl
    mkcert
    ruby
  ];

  # Replaces the module's `mkDefault` list rather than appending to it — see the
  # note in modules/home/ssh/. The personal Yubikey has to be restated because of
  # that: it is what authenticates the dotfiles checkout on every machine.
  programs.ssh.settings."github.com".IdentityFile = [
    personalYubikeyIdentity
    workYubikeyIdentity
  ];

  home.file.".ssh/id_rsa_yubikey_work.pub".source = ./id_rsa_yubikey_work.pub;

  # TODO: retires with the move to hostname-keyed flake outputs — `dot-apply` is
  # its only consumer.
  programs.zsh.sessionVariables.NIX_PROFILE = "work";

  xdg.configFile."gh-dash/config.yml".source =
    lib.mkForce (config.lib.file.mkOutOfStoreSymlink ghDashConfig);
}
