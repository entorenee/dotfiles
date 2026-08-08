{
  config,
  lib,
  ...
}: let
  personalKeyPath = ./public-ssh-keys/id_rsa_yubikey_personal.pub;
  personalYubikeyIdentity = "${config.home.homeDirectory}/.ssh/id_rsa_yubikey_personal.pub";
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."192.168.1.*" = {
      IdentityFile = personalYubikeyIdentity;
      IdentitiesOnly = true;
    };
    settings.hub = {
      HostName = "192.168.1.160";
      User = "skyler";
      IdentityFile = personalYubikeyIdentity;
      IdentitiesOnly = true;
      ServerAliveInterval = 60;
      ServerAliveCountMax = 3;
    };
    settings."github.com" = {
      # The baseline every machine needs: the personal Yubikey is what
      # authenticates the dotfiles checkout everywhere.
      #
      # `mkDefault` is load-bearing: `settings` is a freeform `types.anything`,
      # whose merge *throws* on two list definitions rather than concatenating,
      # so nothing can append here. A host needing more identities replaces the
      # list outright instead — see hosts/darwin/fw-skyler/home.nix, and
      # CLAUDE.md for why priority filtering makes that work.
      IdentityFile = lib.mkDefault [personalYubikeyIdentity];
      IdentitiesOnly = true;
    };
  };

  # Always include personal key file, for dotfiles access
  home.file.".ssh/id_rsa_yubikey_personal.pub".source = personalKeyPath;
}
