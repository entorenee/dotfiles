{ pkgs, nixos-hardware, ... }: {
  imports = [
    # Zero 2W uses BCM2710A1 (same SoC family as Pi 3)
    nixos-hardware.nixosModules.raspberry-pi-3
    ./common.nix
  ];

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

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
}
