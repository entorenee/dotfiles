{
  lib,
  config,
  pkgs,
  profile,
  ...
}: let
  personalKeyPath = ./public-ssh-keys/id_rsa_yubikey_personal.pub;
  workKeyPath = ./public-ssh-keys/id_rsa_yubikey_work.pub;
  isWorkProfile = profile == "work";
  personalYubikeyIdentity = "${config.home.homeDirectory}/.ssh/id_rsa_yubikey_personal.pub";
  workYubikeyIdentity = "${config.home.homeDirectory}/.ssh/id_rsa_yubikey_work.pub";
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."192.168.1.*" = {
      IdentityFile = personalYubikeyIdentity;
      IdentitiesOnly = true;
    };
    settings."github.com" = {
      IdentityFile =
        [personalYubikeyIdentity]
        ++ lib.optional isWorkProfile workYubikeyIdentity;
      IdentitiesOnly = true;
    };
  };

  # Always include personal key file, for dotfiles access
  home.file.".ssh/id_rsa_yubikey_personal.pub".source = personalKeyPath;

  # Conditionally copy work public key for work profile
  home.file.".ssh/id_rsa_yubikey_work.pub" = lib.mkIf isWorkProfile {
    source = workKeyPath;
  };
}
