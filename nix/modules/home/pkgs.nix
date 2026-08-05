{
  lib,
  pkgs,
  ...
}: let
  # Persona package sets live in users/personal/{home,desktop}.nix and
  # hosts/darwin/fw-skyler/home.nix; `home.packages` is a `listOf package`, so
  # their definitions concatenate with this one.
  #
  # Headless-safe Linux CLI/daemon tools only — no display dependency, so this
  # stays platform truth (`pkgs.stdenv.isLinux`) rather than a capability
  # check. GUI-only Linux packages live in modules/home/linux-gui-pkgs.nix,
  # imported only from roles/home/gui.nix — see
  # docs/local/plans/nix-architecture-redesign.md step 5 follow-up for why
  # that split, not an inline `config.my.gui` check here.
  linuxHeadlessPkgs = with pkgs; [
    bubblewrap
    cryptsetup # TODO: Confirm if this is a needed dependency
    docker
    docker-compose
    nodejs_22 # TODO determine dynamic sourcing of Node
    socat
    tor
    z-lua
  ];
in {
  # nixpkgs.config/overlays used to live here, but setting them from inside a
  # home-manager module is a no-op (or an error, on newer home-manager) once a
  # host uses `useGlobalPkgs = true` — there's no separate pkgs left for a
  # home-manager module to configure (see
  # docs/local/plans/nix-architecture-redesign.md §6.3). Both now live in
  # nix/overlays/ and are applied where each config's pkgs is actually
  # constructed (flake.nix, system/darwin.nix), which stays correct regardless
  # of `useGlobalPkgs`.
  home.packages = with pkgs;
    [
      bash # tmux theme needs a more recent version of bash
      bat
      caddy
      cargo # Nix LSP dependency

      fd
      glow
      git-lfs
      gum
      htop
      jq
      npm-check-updates
      pnpm
      postgresql
      python314
      ripgrep
      shellcheck
      tmuxinator
      tree
      update-nix-fetchgit
      wget
    ]
    ++ lib.optionals pkgs.stdenv.isLinux linuxHeadlessPkgs
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.terminal-notifier # claude-code Notification hook banner
      pkgs.yubikey-manager
    ];
}
