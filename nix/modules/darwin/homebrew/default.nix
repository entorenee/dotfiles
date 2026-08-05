{...}: {
  # Persona taps/brews/casks are declared in users/<persona>/darwin.nix; these
  # options are `listOf str`, so their definitions concatenate with these.
  homebrew = {
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
  };
}
