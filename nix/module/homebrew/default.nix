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
      onActivation = {
        cleanup = "uninstall"; # Uninstall anything not declared in Nix
        autoUpdate = false;
        upgrade = false;
      };

      brews = [
        "pinentry"
        "pinentry-mac"
        "Z"
      ];

      casks = [
        "claude"
        "docker-desktop"
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
