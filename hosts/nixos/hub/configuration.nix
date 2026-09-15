{
  pkgs,
  nixos-hardware,
  ...
}: {
  imports = [
    # Safe here only because this Pi is installed in place and never runs the
    # sd-image module whose populateFirmwareCommands nixos-hardware mkForces
    # over. Do not copy this import into an image-built host — see CLAUDE.md.
    nixos-hardware.nixosModules.raspberry-pi-4
    ../../../roles/nixos/base.nix
    ../../../modules/nixos/gpg-yubikey.nix
  ];

  networking.hostName = "hub";
  networking.useDHCP = true;

  # The account set is fully declared, so an imperative `passwd` cannot persist
  # across rebuilds and quietly re-open the password paths closed below.
  # Console recovery is by pulling the SD card.
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

  # Decrypted with sshd's own host key — `age.identityPaths` defaults to the
  # ed25519/rsa entries of services.openssh.hostKeys, which enabling sshd above
  # already provides, so nothing has to be seeded on the card. `path` is the one
  # modules/home/ssh already points claude-friction.github.com at.
  age.secrets.friction-deploy-hub = {
    file = ../../../secrets/friction-deploy-hub.age;
    path = "/home/skyler/.ssh/id_ed25519_friction";
    owner = "skyler";
    mode = "0400";
  };

  # Read-only on entorenee/dotfiles, so it can pull the checkout unattended but
  # never push. hosts/nixos/hub/home.nix decides when ssh reaches for it.
  age.secrets.dotfiles-deploy-hub = {
    file = ../../../secrets/dotfiles-deploy-hub.age;
    path = "/home/skyler/.ssh/id_ed25519_hub";
    owner = "skyler";
    mode = "0400";
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

  # For root only: skyler has home-manager, so ~/.gitconfig takes precedence
  # there. Signing-relevant subset of modules/home/git/config/* — commits are
  # signed with the personal Yubikey plugged in for the occasion.
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
