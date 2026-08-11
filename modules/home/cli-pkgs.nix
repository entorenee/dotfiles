{
  lib,
  pkgs,
  ...
}: let
  # Headless-safe Linux CLI/daemon tools only — no display dependency, which is
  # why the gate is `pkgs.stdenv.isLinux` and not a capability check. GUI-only
  # Linux packages belong in linux-gui-pkgs.nix.
  linuxHeadlessPkgs = with pkgs; [
    bubblewrap
    cryptsetup # TODO: Confirm if this is a needed dependency
    docker
    docker-compose
    nodejs_22 # TODO determine dynamic sourcing of Node
    socat
  ];
in {
  # Dev tooling: language runtimes, package managers, databases, servers.
  # This list reaches every host taking roles/home/cli.nix or above, so nothing
  # a constrained or airgapped host would be made to carry belongs here — small
  # local shell tools go in minimal-pkgs.nix instead.
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
