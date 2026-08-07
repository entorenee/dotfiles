# The private font files are fetched here, in the module that consumes them,
# rather than as a `private-assets` flake input. Stock Nix fetches every locked
# input eagerly, before it knows which outputs actually use them, so a
# `git+ssh://` input forced *every* host to authenticate to GitHub just to
# evaluate -- including the headless Pis, which never import this module and
# have no Yubikey to authenticate with. (Determinate Nix's lazy trees hides
# this on the desktop; hub's stock Nix does not.) A `builtins.fetchGit` inside
# the module is a thunk instead, so only hosts that import roles/home/gui.nix
# ever force it. See CLAUDE.md.
#
# `builtins.fetchGit` rather than a fixed-output `pkgs.fetchgit`: this runs in
# the evaluator as the invoking user, so it can reach the agent holding the
# Yubikey. An FOD would build as `nixbld`, which has no SSH access at all.
#
# Pinned by `rev`, which is also what makes it legal under pure evaluation.
# Verified that a pinned rev resolves offline from ~/.cache/nix/gitv3, so a GUI
# host only authenticates on a cold cache -- not on every rebuild.
#
# The cost is that `nix flake update` no longer covers this: bump the rev by
# hand. That is the right trade only while the assets repo is near-static (one
# commit, unchanged since Jul 2025). If it starts changing often enough that
# hand-bumping becomes the annoyance, move it back to a flake input and take
# the eager fetch instead -- the Pis would then need
# `--override-input private-assets 'path:/dev/null'` again, which is exactly
# the manual step this shape removes. Pick whichever side is bumped less.
{pkgs, ...}: let
  privateAssets = builtins.fetchGit {
    url = "ssh://git@github.com/entorenee/dotfiles-private-assets.git";
    ref = "refs/heads/main";
    rev = "e6c7e33c2608e6bda2891ca45a319694657292a3";
  };

  privateFonts = pkgs.runCommand "private-fonts" {} ''
    mkdir -p $out/share/fonts
    cp -r ${privateAssets}/fonts/* $out/share/fonts/
  '';
in {
  fonts.fontconfig.enable = true;

  home.packages = [
    pkgs.nerd-fonts.sauce-code-pro
    privateFonts
  ];
}
