{ pkgs, yubikey-guide, ... }: {
  environment.etc."yubikey-guide".source = yubikey-guide;

  users.users.skyler = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  environment.systemPackages = with pkgs; [ tmux ];

  system.stateVersion = "26.05";
}
