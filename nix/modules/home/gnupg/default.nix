{
  config,
  pkgs,
  ...
}: let
  # `my.gui` rather than `isLinux`: a headless host has no display for
  # pinentry-gnome3 to draw on and must fall back to the curses prompt.
  # home-manager derives the `pinentry-program` line from this package's
  # `meta.mainProgram`, so no separate `pinentry.program` is needed.
  pinentryPackage =
    if pkgs.stdenv.isDarwin
    then pkgs.pinentry_mac
    else if config.my.gui
    then pkgs.pinentry-gnome3
    else pkgs.pinentry-curses;
in {
  # Nix owns the whole GnuPG stack — binary, agent, scdaemon, and config.
  #
  # This reverses the workaround in c49d565 ("fix: resolve gpg protocol
  # mismatch", Dec 2025), which dropped `programs.gpg.enable` and
  # `services.gpg-agent` and left only hand-written config files for the
  # distro's GnuPG to read. That was the right call at the time and the wrong
  # shape to keep:
  #
  #   * The mismatch was a "two agents, one socket" problem, not a nix problem.
  #     GnuPG components talk over Assuan sockets at a fixed path derived from
  #     the homedir, and the version is never negotiated — whichever gpg-agent
  #     starts first owns the socket, and a gpg of a different version then
  #     fails against it. The 2025 break straddled the 2.2/2.4 boundary (the
  #     `use-keyboxd` line removed in the same commit is 2.4-only).
  #   * The workaround was never a clean surrender either: it still wrote a
  #     *nix store* pinentry path into a config consumed by the *distro's*
  #     agent, so a GC could break the prompt.
  #   * A NixOS host has no distro GnuPG to defer to, so config-only cannot
  #     reach the Pi hosts at all.
  #
  # Suppressing the distro agent needs no masking: home-manager writes
  # `gpg-agent.service` and `gpg-agent{,-ssh,-extra}.socket` into
  # ~/.config/systemd/user/, which outranks /usr/lib/systemd/user/ in systemd's
  # search path, so the same-named distro units are shadowed. All three sockets
  # are enabled below so none of the distro's are left pointing at our service.
  programs.gpg = {
    enable = true;

    # Transcribed from the drduh YubiKey-Guide config that c49d565 moved into a
    # raw file. Keeping it as `settings` is what lets home-manager own
    # ~/.gnupg/gpg.conf; a raw `home.file` for the same path would collide.
    settings = {
      armor = true;
      cert-digest-algo = "SHA512";
      charset = "utf-8";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      keyid-format = "0xlong";
      list-options = "show-uid-validity";
      no-comments = true;
      no-emit-version = true;
      no-greeting = true;
      no-symkey-cache = true;
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      require-cross-certification = true;
      require-secmem = true;
      s2k-cipher-algo = "AES256";
      s2k-digest-algo = "SHA512";
      throw-keyids = true;
      use-agent = true;
      verify-options = "show-uid-validity";
      with-fingerprint = true;
    };

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
    # home-manager defaults this to true, which would emit a `grab` line the
    # hand-written config never had. Keeping it off preserves current behavior:
    # this change is about who *owns* GnuPG, not about changing how it behaves.
    # It is also the safer default here — pinentry grabbing keyboard and mouse
    # is unreliable under Wayland, and this host runs COSMIC. Worth revisiting
    # deliberately, but not as a side effect of the ownership move.
    grabKeyboardAndMouse = false;
    defaultCacheTtl = 60;
    maxCacheTtl = 120;
    pinentry.package = pinentryPackage;
  };

  # No `programs.zsh.initContent` here any more: `enableSshSupport` already
  # exports GPG_TTY and SSH_AUTH_SOCK and runs
  # `gpg-connect-agent updatestartuptty /bye` on shell init — and does it more
  # carefully than the hand-rolled block did, unsetting SSH_AGENT_PID and
  # guarding re-entry with `gnupg_SSH_AUTH_SOCK_by`.
  #
  # The old `ttyname $GPG_TTY` line in gpg-agent.conf is also gone: gpg-agent
  # does not expand shell variables in its config file, so it never did
  # anything. `updatestartuptty` is the mechanism that actually works.
}
