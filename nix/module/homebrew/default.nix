{
  lib,
  profile,
  username,
  ...
}:
let
  profileConfigs = {
    personal = import ./personal.nix;
    work = import ./work.nix;
  };

  profileConfig = profileConfigs.${profile} or {};
  ghosttyModule = import ../ghostty { inherit username; };
  iterm2Module = import ../iterm2 { inherit username; };
  karabinerModule = import ../karabiner { inherit username; };
  nvmModule = import ../nvm { inherit username; };
in
{
  imports = [
    ghosttyModule
    iterm2Module# likely to be deprecated pending trial of ghostty
    karabinerModule
    nvmModule
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
        "slack"
        "vlc"
        "yubico-authenticator"
        "zoom"
      ];
    }
    (profileConfig.homebrew or {})
  ];
}
