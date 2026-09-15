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
  imports = [
    ./claude.nix
  ];

  home.packages = with pkgs; [
    cocoapods
    doctl
    mkcert
    ngrok
    ruby
    temurin-bin-17
  ];

  programs.mise.globalConfig.tools."npm:@posthog/cli" = "latest";

  # Replaces the module's `mkDefault` list rather than appending to it, so the
  # personal Yubikey has to be restated — it authenticates the dotfiles checkout
  # on every machine.
  programs.ssh.settings."github.com".IdentityFile = [
    personalYubikeyIdentity
    workYubikeyIdentity
  ];

  home.file.".ssh/id_rsa_yubikey_work.pub".source = ./id_rsa_yubikey_work.pub;

  age.identityPaths = ["${config.home.homeDirectory}/.config/age/keys.txt"];

  age.secrets.friction-deploy = {
    file = ../../../secrets/friction-deploy-fw-skyler.age;
    path = "${config.home.homeDirectory}/.ssh/id_ed25519_friction";
    mode = "0400";
  };

  xdg.configFile."gh-dash/config.yml".source =
    lib.mkForce (config.lib.file.mkOutOfStoreSymlink ghDashConfig);
}
