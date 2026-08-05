{
  lib,
  pkgs,
  ...
}: {
  # Linux-desktop-only packages, split out of pkgs.nix's former `linuxPkgs` —
  # see docs/local/plans/nix-architecture-redesign.md step 5 follow-up. Only
  # ever imported from roles/home/gui.nix, so no `config.my.gui` check is
  # needed here — self-gated on `pkgs.stdenv.isLinux` alone, the same pattern
  # aerospace/karabiner already use for the reverse (darwin-only) case, since
  # gui.nix also reaches the Macs.
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
  home.file.".local/share/icons/hicolor/scalable/apps/proton-mail.svg" = lib.mkIf pkgs.stdenv.isLinux {
    source = "${pkgs.protonmail-desktop}/share/pixmaps/proton-mail.png";
  };
}
