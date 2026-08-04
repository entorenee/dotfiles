{
  # A machine with a graphical session: terminal emulators, fonts, desktop apps.
  # Modules here still self-gate on `pkgs.stdenv.is*` where they are also
  # platform-specific (aerospace and karabiner are darwin-only, alacritty is the
  # Linux terminal), so importing this role is safe on either platform.
  imports = [
    ./cli.nix

    ../../modules/aerospace
    ../../modules/alacritty
    ../../modules/firefox
    ../../modules/fonts
    ../../modules/ghostty
    ../../modules/karabiner
    ../../modules/keepassxc
    ../../modules/orca-slicer
  ];

  my.gui = true;
}
