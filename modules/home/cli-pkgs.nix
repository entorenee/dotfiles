{
  lib,
  pkgs,
  ...
}: let
  # Headless-safe Linux CLI/daemon tools only — no display dependency, so the
  # gate stays platform truth (`pkgs.stdenv.isLinux`) rather than a capability
  # check. GUI-only Linux packages belong in modules/home/linux-gui-pkgs.nix,
  # which only roles/home/gui.nix imports; that import is the GUI gate, so no
  # inline `config.my.gui` check is needed on either side.
  linuxHeadlessPkgs = with pkgs; [
    bubblewrap
    cryptsetup # TODO: Confirm if this is a needed dependency
    docker
    docker-compose
    nodejs_22 # TODO determine dynamic sourcing of Node
    socat
    tor
  ];
in {
  # Dev tooling: language runtimes, package managers, databases, servers —
  # everything a machine that is actually developed on wants. Nothing that a
  # constrained or airgapped host would be made to carry belongs here, since
  # this list reaches every host taking roles/home/cli.nix or above.
  #
  # Small local shell tools live in minimal-pkgs.nix (imported from
  # roles/home/minimal.nix) instead.
  #
  # Do not set nixpkgs.config or nixpkgs.overlays here: from inside a
  # home-manager module both are a no-op (an error on newer home-manager) once
  # a host sets `useGlobalPkgs = true`. Overlays live in overlays/ and are
  # applied where each config's pkgs is actually built (flake.nix,
  # system/darwin.nix) — see CONVENTIONS.md.
  home.packages = with pkgs;
    [
      bash # tmux theme needs a more recent version of bash
      caddy
      cargo # Nix LSP dependency
      git-lfs
      npm-check-updates
      pnpm
      postgresql
      python314
      shellcheck
      tmuxinator
      update-nix-fetchgit
      wget
    ]
    ++ lib.optionals pkgs.stdenv.isLinux linuxHeadlessPkgs
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.terminal-notifier # claude-code Notification hook banner
      pkgs.yubikey-manager
    ];
}
