{
  system = "aarch64-linux";
  nixosImports = [./configuration.nix];

  # `minimal`, not `cli`: this is a 512MB Zero 2W on an SD card whose whole job
  # is uptime-kuma behind a tunnel. The home-manager here exists so that SSHing
  # in to read logs or edit config is not hostile — a configured shell, prompt
  # and editor plus the small local CLI set — not so the box can develop
  # anything. `cli` would add language runtimes and dev tooling it will never
  # run and cannot afford to store.
  #
  # The username matches `users.users.uptime` in ./configuration.nix; that
  # account exists purely for SSH administration (uptime-kuma itself runs
  # under DynamicUser).
  username = "uptime";
  homeImports = [../../../roles/home/minimal.nix];
}
