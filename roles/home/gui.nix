{
  # A machine with a graphical session: terminal emulators, fonts, desktop apps.
  # Safe to import on either platform — the modules below self-gate on
  # `pkgs.stdenv.is*` where they are also platform-specific.
  imports = [
    ./cli.nix

    ../../modules/home/aerospace
    ../../modules/home/alacritty
    ../../modules/home/firefox
    ../../modules/home/fonts
    ../../modules/home/ghostty
    ../../modules/home/karabiner
    ../../modules/home/linux-gui-pkgs.nix
  ];

  my.gui = true;

  xdg.autostart.enable = true;

  # Mac GUI apps come from Homebrew casks; the copy probe wipes App Management
  # TCC grants.
  targets.darwin.copyApps.enable = false;
}
