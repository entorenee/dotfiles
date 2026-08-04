{lib, ...}: {
  # Cross-cutting capability facts that modules genuinely need to branch on.
  #
  # Deliberately small. Most divergence is expressed by *importing* a module or
  # not (see nix/roles/), and platform truth stays on `pkgs.stdenv.is*`. An
  # option only earns a place here when a module that a host already imports has
  # to behave differently — see docs/local/plans/nix-architecture-redesign.md §5.
  options.my = {
    gui = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this machine has a graphical session.

        Set by roles/home/gui.nix. Distinct from `pkgs.stdenv.isLinux`, which
        only reads as "has a GUI" while the sole Linux host happens to be a
        desktop; a headless Pi is Linux and has no display.
      '';
    };
  };
}
