{
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ./common.nix
  ];
  users.users.skyler.hashedPassword = "$y$j9T$XiFnrrsKYy0ea0nf/iafR1$a4koktWLZR18TfOVCvkUGmQkoSRrqBM17XR8DyI97jA";

  networking.hostName = "zero-airgap";
  networking.useDHCP = false;
  networking.wireless.enable = false;

  services.openssh.enable = false;

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
