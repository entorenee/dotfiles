{
  lib,
  pkgs,
  modulesPath,
  yubikey-guide,
  ...
}: let
  # No home-manager on this host (see ./default.nix), so the gpg.conf and
  # scdaemon.conf that modules/home/gnupg deploys everywhere else are rendered
  # and placed here instead. No `false` branch below: the shared data only ever
  # uses `true` or a string.
  #
  # builtins.toFile, not pkgs.writeText: static text with no derivation
  # references, so it stays out of the aarch64 build.
  gpgConf = builtins.toFile "gpg.conf" (
    lib.concatMapStrings (s: s + "\n")
    (lib.mapAttrsToList (
        name: value:
          if value == true
          then name
          else "${name} ${toString value}"
      )
      (import ../../../modules/home/gnupg/settings.nix))
  );

  # Use pcscd's PC/SC path rather than gnupg's built-in CCID driver; both reach
  # for the reader otherwise and the card goes intermittently unavailable.
  # Depends on pcscd from modules/nixos/gpg-yubikey.nix — with this flag set and
  # no pcscd there is no driver left at all.
  scdaemonConf = builtins.toFile "scdaemon.conf" "disable-ccid\n";
in {
  imports = [
    # Stock sd-image only. Do not add nixos-hardware.nixosModules.raspberry-pi-3
    # here: it mkForce-replaces populateFirmwareCommands and the replacement
    # installs no kernel unless hardware.raspberry-pi.firmware.uboot.enable is
    # also set, which boots to 7 LED flashes. See CLAUDE.md.
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ../../../roles/nixos/base.nix
    ../../../modules/nixos/gpg-yubikey.nix
  ];

  environment.etc."yubikey-guide".source = yubikey-guide;

  networking.hostName = "airgap";
  networking.useDHCP = false;
  networking.wireless.enable = false;

  services.openssh.enable = false;

  users.users.skyler = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    # Console login is the only way in, so unlike hub this host needs a
    # password. Device-specific initial password, not reused anywhere else.
    hashedPassword = "$y$j9T$XiFnrrsKYy0ea0nf/iafR1$a4koktWLZR18TfOVCvkUGmQkoSRrqBM17XR8DyI97jA";
  };

  # `L+` replaces a gpg.conf gnupg wrote itself on first run rather than leaving
  # it in place. Key generation is unaffected: that workflow runs against its own
  # throwaway GNUPGHOME with the guide's config.
  systemd.user.tmpfiles.users.skyler.rules = [
    "d %h/.gnupg 0700 - - -"
    "L+ %h/.gnupg/gpg.conf - - - - ${gpgConf}"
    "L+ %h/.gnupg/scdaemon.conf - - - - ${scdaemonConf}"
  ];

  # `programs.gpg.publicKeys` seeds the keyring on every other host; here the
  # import is manual. Without a public key `gpg -K` prints nothing even with the
  # Yubikey present and readable by `gpg --card-status`: the secret-key listing
  # walks pubring, so the card's shadowed stubs have nothing to attach to. With
  # no network, the only other way to seed it is a USB transfer at the console.
  systemd.user.services.gpg-seed-public-keys = {
    description = "Import GnuPG public keys and mark them ultimately trusted";
    wantedBy = ["default.target"];
    # So the keyring is built with gpg.conf already in place, not with whatever
    # gnupg defaults to before tmpfiles lands it.
    after = ["systemd-tmpfiles-setup.service"];
    serviceConfig.Type = "oneshot";
    path = with pkgs; [gnupg gawk];
    # Both identities: a token whose public key is missing fails the same way
    # whichever one it belongs to, and modules/home/gnupg already installs both
    # public halves fleet-wide. Re-importing is a no-op, so running on every
    # login is safe.
    script = ''
      gpg --batch --quiet --import \
        ${../../../modules/home/gnupg/public-keys/personal-pub.asc} \
        ${../../../modules/home/gnupg/public-keys/freeworld-pub.asc}
      # Only the fpr line following a pub line — subkeys carry their own, and
      # ownertrust is a primary-key property.
      gpg --list-keys --with-colons \
        | awk -F: '$1 == "pub" {p = 1} $1 == "fpr" && p {print $10 ":6:"; p = 0}' \
        | gpg --batch --quiet --import-ownertrust
    '';
  };

  environment.systemPackages = with pkgs; [
    cryptsetup
    diceware
    ent
    paperkey
    parted
    pgpdump
    pwgen
    rng-tools
  ];

  # boot.loader.*, fileSystems."/", and fileSystems."/boot/firmware" are
  # already set by sd-image-aarch64.nix.
}
