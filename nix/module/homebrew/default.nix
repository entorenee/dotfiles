{
  lib,
  profile,
  ...
}: let
  profileConfigs = {
    personal = import ./personal.nix;
    work = import ./work.nix;
  };

  profileConfig = profileConfigs.${profile} or {};
in {
  homebrew = lib.mkMerge [
    {
      enable = true;
      onActivation = {
        cleanup = "uninstall"; # Uninstall anything not declared in Nix
        autoUpdate = false;
        upgrade = false;
      };

      brews = [
        "cspell" # TODO: test using Nix pkg
        "nvm" # TODO find Linux alternative
        "pinentry" # TODO: May be able to substitue with pinentry-tty and pinentry_mac in Nix
        "pinentry-mac"
        "Z" # TODO test moving Mac to pkgs
      ];

      casks = [
        "claude"
        "docker-desktop"
        "elgato-control-center" # TODO find linux pkg
        "firefox" # TODO: look into migrating to Home Manager
        "ghostty"
        "insomnia"
        "jordanbaird-ice"
        "karabiner-elements"
        "obsidian"
        "rectangle"
        "slack"
        "spotify"
        "vlc"
        "yubico-authenticator"
        "zoom"
      ];
    }
    (profileConfig.homebrew or {})
  ];
}
