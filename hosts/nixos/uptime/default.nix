{
  system = "aarch64-linux";
  nixosImports = [./configuration.nix];

  # `minimal`, not `cli`: a 512MB Zero 2W that runs uptime-kuma. Home-manager is
  # here so SSHing in to read logs is not hostile, not so the box can develop
  # anything — `cli`'s language runtimes and dev tooling it cannot afford to
  # store.
  #
  # The username matches `users.users.uptime` in ./configuration.nix, an
  # SSH-administration account; uptime-kuma itself runs under DynamicUser.
  username = "uptime";
  homeImports = [../../../roles/home/minimal.nix];
}
