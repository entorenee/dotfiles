{...}: {
  # The personal role, nix-darwin side.
  homebrew = {
    casks = [
      "backblaze"
      "balenaetcher"
      "calibre"
      "fujitsu-scansnap-home"
      "freefilesync"
      "garmin-express"
      "jellyfin-media-player"
      "keepassxc"
      "libreoffice"
      "little-snitch"
      "nextcloud"
      "orcaslicer"
      "proton-mail"
      "protonvpn"
      "raspberry-pi-imager"
      "signal"
      "steam"
      "tor-browser"
      "veracrypt"
    ];
  };

  system.defaults.dock.persistent-apps = [
    "/Applications/Ghostty.app"
    "/Applications/Obsidian.app"
    "/Applications/Firefox.app"
    "/Applications/Signal.app"
    "/Applications/KeePassXC.app"
    "/Applications/Proton Mail.app"
    "/Applications/ProtonVPN.app"
    "/Applications/Yubico Authenticator.app"
    "/Applications/OrcaSlicer.app"
  ];
}
