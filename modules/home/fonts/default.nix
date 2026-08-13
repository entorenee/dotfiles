# Fetched here, in its only consumer, rather than as a flake input: stock Nix
# fetches every locked input eagerly, so a `git+ssh://` input would make every
# host authenticate to GitHub just to evaluate — including the Pis, which never
# import this module and hold no Yubikey. This is a thunk only importing hosts
# force.
#
# Must be `builtins.fetchGit`, not a fixed-output `pkgs.fetchgit`: this runs in
# the evaluator as the invoking user and can reach the agent holding the
# Yubikey, where an FOD builds as `nixbld` and has no SSH access.
#
# Bump `rev` by hand — `nix flake update` does not cover it. See
# PRIVATE-ASSETS.md for when to reverse this shape.
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
