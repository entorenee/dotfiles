{
  system = "aarch64-linux";
  nixosImports = [./configuration.nix];
  # No home-manager, deliberately: this is an air-gapped single-purpose
  # appliance for the Yubikey workflow, and `environment.systemPackages` in
  # roles/nixos/base.nix covers everything it needs.
}
