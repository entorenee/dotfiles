{ pkgs, yubikey-guide, ... }: {
  environment.etc."yubikey-guide".source = yubikey-guide;

  # nixos-hardware's raspberry-pi modules mkForce-override the
  # populateFirmwareCommands from sd-image-aarch64.nix, and their replacement
  # only installs u-boot.bin (and emits the matching config.txt `kernel=` and
  # `arm_64bit=1` lines) when this is set. Left off, the firmware partition gets
  # bootcode.bin/start.elf/dtbs but no kernel at all, so the GPU firmware has
  # nothing to hand off to and the board fails with 7 LED flashes.
  hardware.raspberry-pi.firmware.uboot.enable = true;

  users.users.skyler = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  environment.systemPackages = with pkgs; [ tmux ];

  system.stateVersion = "26.05";
}
