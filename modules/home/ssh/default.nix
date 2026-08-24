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
      # whose merge *throws* on two list definitions rather than concatenating.
      # A host needing more identities replaces this list outright.
      IdentityFile = lib.mkDefault [personalYubikeyIdentity];
      IdentitiesOnly = true;
    };
    # An alias, not an override: the friction log is pushed by `git-sync` with
    # no one at the keyboard, and matching `github.com` above would pin the
    # Yubikey and demand a touch. A new attribute key, so no list-merge hazard.
    # The private half is a write-scoped deploy key on that repo alone.
    settings."claude-friction.github.com" = {
      HostName = "github.com";
      IdentityFile = "${config.home.homeDirectory}/.ssh/id_ed25519_friction";
      IdentitiesOnly = true;
    };
  };

  home.file.".ssh/id_rsa_yubikey_personal.pub".source = personalKeyPath;
}
