{
  lib,
  pkgs,
  ...
}: {
  # rtk (Rust Token Killer) — token-optimizing CLI proxy. The rtk-rewrite Claude
  # hook lives in the claude module; this module owns the binary and its config.
  #
  # Verifying an install, and the one failure mode worth knowing:
  #
  #   rtk --version   # expect `rtk X.Y.Z`
  #   rtk gain        # token-savings analytics; also proves the binary is the right one
  #   which rtk       # expect a Nix profile path
  #
  # If `rtk gain` reports "command not found" or an unknown subcommand, the
  # binary on PATH is probably reachingforthejack/rtk (Rust Type Kit) — a
  # different project with the same name.
  #
  # `rtk gain --history` and `rtk discover` are the other meta commands; both are
  # for a human reading savings, not for a session. Deliberately not documented in
  # the Claude context: they were in an `@`-imported RTK.md until 2026-08-21, which
  # meant ~34 lines of setup notes loaded in every session in every repo to serve a
  # command nobody runs mid-task. The four facts a session actually needs are in
  # the claude module's CLAUDE.md under "Bash".
  home.packages = [pkgs.rtk];

  # Deploy the config to rtk's platform-specific location. macOS resolves to
  # ~/Library/Application Support/rtk/config.toml; Linux follows XDG.
  home.file = lib.mkIf pkgs.stdenv.isDarwin {
    "Library/Application Support/rtk/config.toml".source = ./config/config.toml;
  };

  xdg.configFile = lib.mkIf pkgs.stdenv.isLinux {
    "rtk/config.toml".source = ./config/config.toml;
  };
}
