{
  lib,
  pkgs,
  ...
}: {
  # sd-image-aarch64.nix enables ZFS through the default supportedFilesystems,
  # and it will not build for the aarch64 image. Every host under hosts/ is a
  # Pi, so force it off here rather than repeating it per host.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # nixos-hardware's Pi profiles default to Raspberry Pi's vendor kernel, which
  # nothing publishes to cache.nixos.org (no Hydra jobset: nixos-hardware#854),
  # so it costs an 8+ hour on-device compile. Mainline is cached and enough for
  # these headless boards. Plain definition, so it beats the profile's mkDefault.
  # Kernel changes need `nixos-rebuild boot` + reboot, not switch -- see CLAUDE.md.
  boot.kernelPackages = pkgs.linuxPackages;

  environment.systemPackages = with pkgs; [neovim tmux];

  system.stateVersion = "26.05";
}
