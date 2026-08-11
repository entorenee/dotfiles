{
  system = "aarch64-linux";
  nixosImports = [./configuration.nix];

  # `minimal`, not `cli`: a 512MB Zero 2W that cannot afford `cli`'s language
  # runtimes. Home-manager is here so SSHing in to read logs is not hostile,
  # not so the box can develop anything.
  username = "uptime";
  homeImports = [../../../roles/home/minimal.nix];
}
