{
  config,
  lib,
  ...
}: let
  ghDashConfig = "${config.home.homeDirectory}/dotfiles/nix/users/personal/gh-dash.yml";
in {
  # Personal identity, home-manager side — the portable subset, safe for any
  # machine that is "me personally", headless or not. GUI-desktop-only pieces
  # (keepassxc, orca-slicer, go, hugo) live in ./desktop.nix instead, opted into
  # per-host via `extraHomeImports` — see
  # docs/local/plans/nix-architecture-redesign.md §4c.
  imports = [
    ./claude.nix
  ];

  # No ssh block: the personal Yubikey is the module's default identity.

  xdg.configFile."gh-dash/config.yml".source =
    lib.mkForce (config.lib.file.mkOutOfStoreSymlink ghDashConfig);

  services.syncthing.enable = true;
}
