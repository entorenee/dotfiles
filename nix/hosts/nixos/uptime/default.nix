{
  system = "aarch64-linux";
  nixosImports = [./configuration.nix];
  # No home-manager yet. Unlike airgap, this host wants a minimal one for
  # terminal utilities — that lands in its own commit so this one stays
  # provably behaviour-preserving.
}
