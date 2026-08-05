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
      # `mkDefault` is load-bearing, not decorative. `settings` is a freeform
      # `types.anything`, whose merge *throws* on two list definitions instead of
      # concatenating them — so a persona cannot append here. Priority filtering
      # runs before the type's merge, though, so marking this as a default means
      # a persona that needs more identities (see users/work/home.nix) replaces
      # the list outright and only one definition ever reaches the merge.
      IdentityFile = lib.mkDefault [personalYubikeyIdentity];
      IdentitiesOnly = true;
    };
  };

  # Always include personal key file, for dotfiles access
  home.file.".ssh/id_rsa_yubikey_personal.pub".source = personalKeyPath;
}
