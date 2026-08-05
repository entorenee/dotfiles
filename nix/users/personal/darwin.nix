{...}: {
  # Personal identity, nix-darwin side. Only the personal Mac imports this.
  homebrew = {
    brews = [
      "tor"
    ];

    casks = [
      "anylist"
      "backblaze"
      "balenaetcher"
      "calibre"
      "discord"
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
      "proton-pass" #deprecating usage of
      "protonvpn"
      "raspberry-pi-imager"
      "signal"
      "sweet-home3d"
      "steam"
      "tpvirtual"
      "tor-browser"
      "veracrypt"
    ];
  };

  system.defaults.dock.persistent-apps = [
    "/Applications/Ghostty.app"
    "/Applications/Obsidian.app"
    "/Applications/Firefox.app"
    "/Applications/Signal.app"
    "/Applications/Slack.app"
    "/Applications/Discord.app"
    "/Applications/KeePassXC.app"
    "/Applications/Proton Mail.app"
    "/Applications/ProtonVPN.app"
    "/Applications/Yubico Authenticator.app"
    "/Applications/OrcaSlicer.app"
  ];
}
