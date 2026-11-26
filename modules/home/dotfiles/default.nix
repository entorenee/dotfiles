{
  config,
  lib,
  ...
}: let
  repoRoot = ../../..;
  # One indirection for every mutable link, so a rebuild from another checkout
  # (a worktree) repoints them all by moving this symlink. Eval stays pure: the
  # store only ever records this fixed path, never where it resolves.
  pointer = "${config.xdg.stateHome}/dotfiles/active";
in {
  # `link ./config` from any module in this repo: a live symlink through the
  # pointer where the machine has a checkout, a store copy where it does not.
  lib.dotfiles.link = path:
    if config.my.dotfiles.mutable
    then
      config.lib.file.mkOutOfStoreSymlink
      "${pointer}/${lib.removePrefix "./" (lib.path.removePrefix repoRoot path)}"
    else path;

  # Seed only — never overwrite. `make rebuild` owns repointing, so an
  # activation from a worktree does not silently snap the pointer back.
  home.activation.seedDotfilesPointer = lib.mkIf config.my.dotfiles.mutable (
    lib.hm.dag.entryBefore ["linkGeneration"] ''
      if [ ! -e ${lib.escapeShellArg pointer} ] && [ ! -L ${lib.escapeShellArg pointer} ]; then
        run mkdir -p ${lib.escapeShellArg (builtins.dirOf pointer)}
        run ln -s ${lib.escapeShellArg "${config.home.homeDirectory}/dotfiles/main"} ${lib.escapeShellArg pointer}
      fi
    ''
  );
}
