{
  lib,
  pkgs,
  ...
}: {
  # sd-image-aarch64.nix enables ZFS through the default supportedFilesystems,
  # and it will not build for the aarch64 image. Every host under nix/hosts is a
  # Pi, so force it off here rather than repeating it per host.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  environment.systemPackages = with pkgs; [neovim tmux];

  system.stateVersion = "26.05";
}
