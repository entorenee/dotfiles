{lib, ...}: {
  # Cross-cutting capability facts that modules genuinely need to branch on.
  #
  # Deliberately small. Most divergence is expressed by *importing* a module or
  # not (see roles/), and platform truth stays on `pkgs.stdenv.is*`. An
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

    dotfiles.mutable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether this machine has a live `~/dotfiles` checkout to symlink
        config against.

        `true` (the default, matching every host before this option existed)
        deploys the config via `config.lib.file.mkOutOfStoreSymlink`, so
        editing the repo file takes effect without a rebuild. `false` (every
        Pi — see docs/local/plans/nix-architecture-redesign.md §6.1) deploys
        a plain store copy instead, since a Pi's checkout may not exist or
        may not have run yet when home-manager activates.

        Transitional: once out-of-store symlinks are retired everywhere,
        this collapses to a constant and gets deleted (§6.4). Do not grow it
        into a general mutability framework.
      '';
    };
  };
}
