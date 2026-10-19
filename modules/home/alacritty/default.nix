{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux {
  programs.alacritty = {
    enable = true;
    # Run under XWayland so ueberzugpp's X11 output can find the window; its
    # Wayland output doesn't support COSMIC.
    package = pkgs.symlinkJoin {
      pname = "alacritty-x11";
      # home-manager picks the theme import key from the version.
      inherit (pkgs.alacritty) version;
      paths = [pkgs.alacritty];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/alacritty --unset WAYLAND_DISPLAY
      '';
    };
    theme = "tokyo_night";

    settings = {
      font = {
        normal = {
          family = "Dank Mono";
          style = "monospace";
        };
      };
    };
  };
}
