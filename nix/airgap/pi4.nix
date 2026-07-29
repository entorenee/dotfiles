{ pkgs, nixos-hardware, ... }: {
  imports = [
    nixos-hardware.nixosModules.raspberry-pi-4
    ./common.nix
  ];

  networking.hostName = "pi4-online";
  networking.useDHCP = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # skyler is in the wheel group but has no password, so password-authenticated
  # sudo can't work. Allow wheel to sudo without a password (login is SSH-key
  # only) so USB drives can be mounted when staging the airgapped Pi's files.
  security.sudo.wheelNeedsPassword = false;

  users.users.skyler.openssh.authorizedKeys.keyFiles = [
    ../module/ssh/public-ssh-keys/id_rsa_yubikey_personal.pub
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    git
    gnumake
    rsync
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
}
