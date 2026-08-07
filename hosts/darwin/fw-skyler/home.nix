{
  config,
  lib,
  pkgs,
  ...
}: let
  personalYubikeyIdentity = "${config.home.homeDirectory}/.ssh/id_rsa_yubikey_personal.pub";
  workYubikeyIdentity = "${config.home.homeDirectory}/.ssh/id_rsa_yubikey_work.pub";
  ghDashConfig = "${config.home.homeDirectory}/dotfiles/hosts/darwin/fw-skyler/gh-dash.yml";
in {
  # fw-skyler is the only work machine, so work identity lives directly on the
  # host rather than in a shared role under roles/home/ — this host names
  # ./home.nix and ./darwin.nix in its own import lists. See
  # docs/local/plans/nix-architecture-redesign.md §4c.
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

  xdg.configFile."gh-dash/config.yml".source =
    lib.mkForce (config.lib.file.mkOutOfStoreSymlink ghDashConfig);
}
