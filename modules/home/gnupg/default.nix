{
  config,
  pkgs,
  ...
}: let
  pinentryPackage =
    if pkgs.stdenv.isDarwin
    then pkgs.pinentry_mac
    else if config.my.gui
    then pkgs.pinentry-gnome3
    else pkgs.pinentry-curses;
in {
  # Nix owns the whole GnuPG stack — binary, agent, scdaemon, and config.
  programs.gpg = {
    enable = true;

    # Also read by hosts/nixos/airgap — see ./settings.nix.
    settings = import ./settings.nix;

    # Yubikey: use the internal CCID driver via pcscd rather than gnupg's own.
    scdaemonSettings.disable-ccid = true;

    publicKeys = [
      {
        source = ./public-keys/personal-pub.asc;
        trust = "ultimate";
      }
      {
        source = ./public-keys/freeworld-pub.asc;
        trust = "ultimate";
      }
    ];
  };

  services.gpg-agent = {
    enable = true;
    # Explicit, not decorative: home-manager emits `disable-scdaemon` whenever
    # this is false, which would cut off the Yubikey entirely.
    enableScDaemon = true;
    enableSshSupport = true;
    # Defaults to false; enabled so home-manager owns the same socket set the
    # distro had enabled and leaves no orphaned unit behind.
    enableExtraSocket = true;
    # home-manager defaults this to true, which emits a `grab` line. Keep it
    # off: pinentry grabbing keyboard and mouse is unreliable under Wayland,
    # and the Linux desktop here runs COSMIC.
    grabKeyboardAndMouse = false;
    defaultCacheTtl = 60;
    maxCacheTtl = 120;
    pinentry.package = pinentryPackage;
  };

  # No `programs.zsh.initContent` block belongs here: `enableSshSupport` already
  # exports GPG_TTY and SSH_AUTH_SOCK and runs
  # `gpg-connect-agent updatestartuptty /bye` on shell init, unsetting
  # SSH_AGENT_PID and guarding re-entry with `gnupg_SSH_AUTH_SOCK_by`.
  #
  # Do not add a `ttyname $GPG_TTY` line to gpg-agent.conf: gpg-agent does not
  # expand shell variables in its config file, so it does nothing.
  # `updatestartuptty` is the mechanism that works.
}
