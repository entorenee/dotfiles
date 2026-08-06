{
  username = "skyler.lemay";
  system = "aarch64-darwin";
  homeImports = [
    ../../roles/home/gui.nix
    ../../roles/home/personal.nix
    ../../roles/home/personal-desktop.nix
  ];
  darwinImports = [../../roles/darwin/personal.nix];
}
