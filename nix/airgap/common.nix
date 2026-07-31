{
  lib,
  pkgs,
  yubikey-guide,
  ...
}: {
  environment.etc."yubikey-guide".source = yubikey-guide;

  boot.supportedFilesystems.zfs = lib.mkForce false;

  users.users.skyler = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };

  environment.systemPackages = with pkgs; [tmux];

  system.stateVersion = "26.05";
}
