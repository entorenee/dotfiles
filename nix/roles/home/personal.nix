{
  config,
  lib,
  ...
}: let
  ghDashConfig = "${config.home.homeDirectory}/dotfiles/nix/roles/home/personal-gh-dash.yml";
in {
  # The personal role, home-manager side — the portable subset, safe for any
  # machine doing the "personal" job, headless or not. GUI-desktop-only pieces
  # (keepassxc, orca-slicer, go, hugo) live in ./personal-desktop.nix instead,
  # which a host adds to its own `homeImports` list.
  imports = [
    ./personal-claude.nix
  ];

  # No ssh block: the personal Yubikey is the module's default identity.

  xdg.configFile."gh-dash/config.yml".source =
    lib.mkForce (config.lib.file.mkOutOfStoreSymlink ghDashConfig);

  services.syncthing.enable = true;
}
