{...}: {
  # Identity taps/brews/casks live in the role a host names in its
  # `darwinImports`; these are `listOf str`, so the definitions concatenate.
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

    # Do not add gnupg / pinentry / pinentry-mac here: nix owns the whole GnuPG
    # stack (see modules/home/gnupg), and a second installation sharing one
    # ~/.gnupg races for the agent socket. macOS has no systemd unit shadowing
    # to arbitrate it, so whichever agent spawns first wins.
    brews = [
      "nvm"
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
