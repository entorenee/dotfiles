{
  lib,
  pkgs,
  profile,
  ...
}: let
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

  linuxPkgs = with pkgs; [
    calibre
    cryptsetup
    cspell
    discord
    docker
    docker-compose
    firefox
    freefilesync
    insomnia
    keepassxc
    libreoffice
    nextcloud-client
    nodejs_20 # TODO determine dynamic sourcing of Node
    orca-slicer
    obsidian
    pcsc-tools
    pinentry-gnome3
    protonmail-desktop
    protonvpn-gui
    signal-desktop
    slack
    spotify
    tor
    veracrypt # TODO see if this still applies of switch to luks
    yubikey-personalization
    yubioath-flutter
    z-lua
  ];
in {
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
  home.packages = with pkgs;
    [
      bash # tmux theme needs a more recent version of bash
      bat
      caddy
      cargo # Nix LSP dependency
      claude-code
      fd
      glow
      git-lfs
      git-up
      gum
      htop
      jq
      npm-check-updates
      postgresql
      python314
      ripgrep
      tmuxinator
      tree
      update-nix-fetchgit
      wget
      yubikey-manager
    ]
    ++ lib.optionals isWorkProfile workPkgs
    ++ lib.optionals isPersonalProfile personalPkgs
    ++ linuxPkgs;
}
