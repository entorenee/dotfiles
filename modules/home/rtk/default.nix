{
  lib,
  pkgs,
  ...
}: {
  # rtk (Rust Token Killer) — token-optimizing CLI proxy. The rtk-rewrite Claude
  # hook lives in the claude module; this module owns the binary and its config.
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
