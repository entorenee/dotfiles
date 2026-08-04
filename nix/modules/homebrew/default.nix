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
        # Homebrew >=5.1.15 requires --force/--force-cleanup/$HOMEBREW_ASK
        # when `brew bundle --cleanup` is used non-interactively.
        extraFlags = ["--force"];
      };

      # AeroSpace ships from the maintainer's tap, not homebrew-cask core.
      taps = [
        "nikitabobko/tap"
      ];

      brews = [
        "gnupg"
        "nvm"
        "pinentry"
        "pinentry-mac"
        "Z"
      ];

      casks = [
        "nikitabobko/tap/aerospace"
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
