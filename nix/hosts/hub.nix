{
  pkgs,
  nixos-hardware,
  ...
}: {
  imports = [
    # Safe here, unlike on the sd-image hosts: this Pi is installed in place and
    # rebuilt with `make hub-switch`, so it never runs the sd-image module whose
    # populateFirmwareCommands nixos-hardware would mkForce over. Do not copy
    # this import into an image-built host. See CLAUDE.md.
    nixos-hardware.nixosModules.raspberry-pi-4
    ./common.nix
  ];

  networking.hostName = "hub";
  networking.useDHCP = true;

  users.users.skyler = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keyFiles = [
      ../module/ssh/public-ssh-keys/id_rsa_yubikey_personal.pub
    ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # skyler is in the wheel group but has no password, so password-authenticated
  # sudo can't work. Allow wheel to sudo without a password (login is SSH-key
  # only) so USB drives can be mounted when staging the airgapped Pi's files.
  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = ["nix-command" "flakes"];

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
