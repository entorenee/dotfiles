{lib, ...}: {
  # Cross-cutting capability facts that modules genuinely need to branch on.
  #
  # Deliberately small. Most divergence is expressed by *importing* a module or
  # not (see roles/), and platform truth stays on `pkgs.stdenv.is*`. An option
  # only earns a place here when a module that a host already imports has to
  # behave differently — see CONVENTIONS.md.
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

        `true` deploys the config via `config.lib.file.mkOutOfStoreSymlink`,
        so editing the repo file takes effect without a rebuild. `false`
        (every Pi) deploys a plain store copy instead, since a Pi's checkout
        may not exist, or may not have been cloned yet, when home-manager
        activates.

        Transitional: once out-of-store symlinks are retired everywhere, this
        collapses to a constant and gets deleted. Do not grow it into a
        general mutability framework.
      '';
    };
  };
}
