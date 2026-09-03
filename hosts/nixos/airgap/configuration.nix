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

  environment.systemPackages = with pkgs; [
    # Generates the break-glass age identity, which must never touch a
    # networked disk. Bare `age`, not `pkgs.agenix`: this host is not an agenix
    # consumer and cannot become one — services.openssh.enable = false above
    # leaves age.identityPaths at [], which trips agenix's assertion the moment
    # any age.secrets is declared here.
    age
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
