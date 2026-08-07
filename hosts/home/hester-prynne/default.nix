{
  username = "skyler.lemay";
  system = "x86_64-linux";
  homeImports = [
    ../../../roles/home/gui.nix
    ../../../roles/home/personal.nix
    ../../../roles/home/personal-desktop.nix
    ./autostart-suppression.nix
  ];
  # protonmail-desktop (the nixpkgs package, not the Mac Homebrew cask) only
  # ever appears in this host's Linux-only package list.
  overlays = [(import ../../../overlays/protonmail-desktop.nix)];
}
