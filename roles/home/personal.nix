{
  config,
  lib,
  pkgs,
  ...
}: {
  # The personal role, home-manager side — the portable subset, safe for any
  # machine doing the "personal" job, headless or not. Anything needing a GUI
  # desktop goes in ./personal-desktop.nix instead.
  imports = [./personal-claude.nix];

  # No ssh block: the personal Yubikey is the module's default identity.

  home.packages = [pkgs.tor];

  xdg.configFile."gh-dash/config.yml".source =
    lib.mkForce (config.lib.dotfiles.link ./personal-gh-dash.yml);

  services.syncthing.enable = true;
}
