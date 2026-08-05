{
  lib,
  pkgs,
  ...
}: let
  # Persona package sets live in users/personal/{home,desktop}.nix and
  # hosts/darwin/fw-skyler/home.nix; `home.packages` is a `listOf package`, so
  # their definitions concatenate with this one.
  linuxPkgs = with pkgs; [
    arduino-ide
    bubblewrap
    caffeine-ng
    calibre
    cryptsetup # TODO: Confirm if this is a needed dependency
    docker
    docker-compose
    freefilesync
    insomnia
    jellyfin-desktop
    libnotify # notify-send, for the claude-code Notification hook banner
    libreoffice
    nextcloud-client
    nodejs_22 # TODO determine dynamic sourcing of Node
    obsidian
    pinentry-gnome3
    protonmail-desktop
    rpi-imager
    signal-desktop
    slack
    socat
    spotify
    tor
    veracrypt
    zoom-us
    z-lua
  ];
in {
  # nixpkgs.config/overlays used to live here, but setting them from inside a
  # home-manager module is a no-op (or an error, on newer home-manager) once a
  # host uses `useGlobalPkgs = true` — there's no separate pkgs left for a
  # home-manager module to configure (see
  # docs/local/plans/nix-architecture-redesign.md §6.3). Both now live in
  # nix/overlays/ and are applied where each config's pkgs is actually
  # constructed (flake.nix, system/darwin.nix), which stays correct regardless
  # of `useGlobalPkgs`.
  home.packages = with pkgs;
    [
      bash # tmux theme needs a more recent version of bash
      bat
      caddy
      cargo # Nix LSP dependency

      fd
      glow
      git-lfs
      gum
      htop
      jq
      npm-check-updates
      pnpm
      postgresql
      python314
      ripgrep
      shellcheck
      tmuxinator
      tree
      update-nix-fetchgit
      wget
    ]
    ++ lib.optionals pkgs.stdenv.isLinux linuxPkgs
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.terminal-notifier # claude-code Notification hook banner
      pkgs.yubikey-manager
    ];

  # proton-mail.png is actually SVG content; placing it in hicolor/scalable lets
  # GNOME find it reliably (pixmaps/ is not consistently searched from Nix profiles).
  home.file.".local/share/icons/hicolor/scalable/apps/proton-mail.svg" = lib.mkIf pkgs.stdenv.isLinux {
    source = "${pkgs.protonmail-desktop}/share/pixmaps/proton-mail.png";
  };
}
