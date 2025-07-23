{
  lib,
  pkgs,
  profile,
  ...
}:
let
  isWorkProfile = profile == "work";
  workPkgs = with pkgs; [
    doctl
    mkcert
  ];

  isPersonalProfile = profile == "personal";
  personalPkgs = with pkgs; [
    go
    hugo
  ];
in
{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
  home.packages =
    with pkgs;
    [
      bash # tmux theme needs a more recent version of bash
      bat
      cargo # Nix LSP dependency
      git-lfs
      git-up
      htop
      jq
      postgresql
      python314
      ripgrep
      tmuxinator
      tree
      wget
      yubikey-manager
    ]
      ++ lib.optionals isWorkProfile workPkgs
      ++ lib.optionals isPersonalProfile personalPkgs;
}
