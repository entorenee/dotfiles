{
  # A machine with a graphical session: terminal emulators, fonts, desktop apps.
  # Modules here still self-gate on `pkgs.stdenv.is*` where they are also
  # platform-specific (aerospace and karabiner are darwin-only, alacritty is the
  # Linux terminal), so importing this role is safe on either platform.
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
}
