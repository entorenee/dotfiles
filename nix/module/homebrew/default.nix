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
  iterm2Module = import ../iterm2 { inherit username; };
in
{
  imports = [
    iterm2Module# likely to be deprecated pending trial of ghostty
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
        "npm-check-updates"
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
