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
    ../../../roles/nixos/base.nix
    ../../../modules/nixos/gpg-yubikey.nix
  ];

  networking.hostName = "hub";
  networking.useDHCP = true;

  # The account set is fully declared here, so /etc/shadow should not be able to
  # drift out from under it -- an imperative `passwd` would otherwise persist
  # across rebuilds and quietly re-open the password paths closed below.
  # skyler stays passwordless: SSH keys get in, wheelNeedsPassword = false
  # covers sudo, and console recovery is by pulling the SD card.
  users.mutableUsers = false;

  users.users.skyler = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keyFiles = [
      ../../../modules/home/ssh/public-ssh-keys/id_rsa_yubikey_personal.pub
    ];
  };

  # KbdInteractiveAuthentication defaults to true and UsePAM is on, which leaves
  # a PAM keyboard-interactive path to password auth that PasswordAuthentication
  # = false does not cover. PermitRootLogin defaults to "prohibit-password",
  # which still permits key-based root login. Both are closed explicitly, and
  # match uptime.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
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

  # System-wide git config, for root only: skyler has home-manager (see the
  # homeImports in ./default.nix), so ~/.gitconfig takes precedence there, while
  # root has no home-manager identity of its own.
  # Signing-relevant subset of modules/home/git/config/{config,config-personal} —
  # commits are signed with the personal Yubikey plugged in for the occasion.
  environment.etc."gitconfig".text = ''
    [user]
      email = 26767995+entorenee@users.noreply.github.com
      name = Skyler Lemay
      signingkey = 785A45A23EA2C574!

    [commit]
      gpgsign = true
    [tag]
      gpgsign = true
    [init]
      defaultBranch = main

    [url "git@github.com:"]
      insteadOf = https://github.com/
  '';

  # Kernel comes from the mainline pin in roles/nixos/base.nix. The profile above stays
  # imported for the bcm2711 deviceTree filter and the pcie-brcmstb /
  # reset-raspberrypi initrd modules this board's PCIe bus and ethernet need.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
}
