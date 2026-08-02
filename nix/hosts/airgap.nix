{
  pkgs,
  modulesPath,
  yubikey-guide,
  ...
}: {
  imports = [
    # Stock sd-image only. Do not add nixos-hardware.nixosModules.raspberry-pi-3
    # here: it mkForce-replaces populateFirmwareCommands and the replacement
    # installs no kernel unless hardware.raspberry-pi.firmware.uboot.enable is
    # also set, which boots to 7 LED flashes. See CLAUDE.md.
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ./common.nix
  ];

  environment.etc."yubikey-guide".source = yubikey-guide;

  networking.hostName = "airgap";
  networking.useDHCP = false;
  networking.wireless.enable = false;

  services.openssh.enable = false;

  users.users.skyler = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    # Console login is the only way in, so unlike hub.nix this host needs a
    # password. Device-specific initial password, not reused anywhere else.
    hashedPassword = "$y$j9T$XiFnrrsKYy0ea0nf/iafR1$a4koktWLZR18TfOVCvkUGmQkoSRrqBM17XR8DyI97jA";
  };

  services.pcscd.enable = true;

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  environment.systemPackages = with pkgs; [
    cryptsetup
    diceware
    ent
    gnupg
    paperkey
    parted
    pgpdump
    pinentry-curses
    pwgen
    rng-tools
    yubikey-manager
    yubikey-personalization
  ];

  # boot.loader.*, fileSystems."/", and fileSystems."/boot/firmware" are
  # already set by sd-image-aarch64.nix.
}
