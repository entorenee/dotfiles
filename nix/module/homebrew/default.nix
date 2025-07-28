{
  lib,
  profile,
  ...
}:
let
  profileConfigs = {
    personal = import ./personal.nix;
    work = import ./work.nix;
  };

  profileConfig = profileConfigs.${profile} or {};
in
{

  homebrew = lib.mkMerge [
    {
      enable = true;
      onActivation = {
        cleanup = "uninstall"; # Uninstall anything not declared in Nix
        autoUpdate = false;
        upgrade = false;
      };

      brews = [
        "nvm"
        "pinentry"
        "pinentry-mac"
        "Z"
      ];

      casks = [
        "claude"
        "docker-desktop"
        "elgato-control-center"
        "firefox" # TODO: look into migrating to Home Manager
        "ghostty"
        "insomnia"
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
