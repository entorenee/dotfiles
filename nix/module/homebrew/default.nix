{ profile, lib, ... }:
let
  profileConfigs = {
    personal = import ./personal.nix;
    work = import ./work.nix;
  };

  profileConfig = profileConfigs.${profile} or {};
in
{
  imports = [
    ../ghostty
    ../iterm2 # likely to be deprecated pending trial of ghostty
    ../karabiner
    ../nvm
  ];

  homebrew = lib.mkMerge [
    {
      enable = true;
      global.autoUpdate = false;
      # TODO: review installs and set cleanup to zap

      brews = [
        "pinentry"
        "pinentry-mac"
        "Z"
      ];

      casks = [
        "docker"
        "elgato-control-center"
        "firefox" # TODO: look into migrating to Home Manager
        "iterm2"
        "karabiner-elements"
        "obsidian"
        "rectangle"
        "vlc"
        "yubico-authenticator"
        "zoom"
      ];
    }
    (profileConfig.homebrew or {})
  ];
}
