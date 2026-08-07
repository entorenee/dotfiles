{
  system = "aarch64-linux";
  nixosImports = [./configuration.nix];
  # The always-on Pi 4 is the one Pi with a real login, so it takes a role
  # stack the same way the Macs do. `cli` rather than `gui`: headless board.
  username = "skyler";
  homeImports = [../../../roles/home/cli.nix];
}
