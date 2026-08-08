{
  lib,
  pkgs,
  ...
}: {
  # Linux-desktop-only packages. Only ever imported from roles/home/gui.nix, so
  # that import is the GUI gate and no `config.my.gui` check is needed here —
  # `pkgs.stdenv.isLinux` alone is enough, and is still required because gui.nix
  # also reaches the Macs. Same self-gating pattern aerospace/karabiner use for
  # the reverse (darwin-only) case.
  home.packages = lib.optionals pkgs.stdenv.isLinux (with pkgs; [
    arduino-ide
    caffeine-ng
    calibre
    freefilesync
    insomnia
    jellyfin-desktop
    libnotify # notify-send, for the claude-code Notification hook banner
    libreoffice
    nextcloud-client
    obsidian
    pinentry-gnome3
    protonmail-desktop
    rpi-imager
    signal-desktop
    slack
    spotify
    veracrypt
    zoom-us
  ]);

  # proton-mail.png is actually SVG content; placing it in hicolor/scalable lets
  # GNOME find it reliably (pixmaps/ is not consistently searched from Nix profiles).
  xdg.dataFile."icons/hicolor/scalable/apps/proton-mail.svg" = lib.mkIf pkgs.stdenv.isLinux {
    source = "${pkgs.protonmail-desktop}/share/pixmaps/proton-mail.png";
  };
}
