{
  lib,
  pkgs,
  profile,
  ...
}: let
  isWorkProfile = profile == "work";
  workPkgs = with pkgs; [
    cocoapods
    doctl
    mkcert
    ruby
  ];

  isPersonalProfile = profile == "personal";
  personalPkgs = with pkgs; [
    go
    hugo
  ];

  linuxPkgs = with pkgs; [
    arduino-ide
    bubblewrap
    calibre
    cryptsetup # TODO: Confirm if this is a needed dependency
    docker
    docker-compose
    freefilesync
    insomnia
    jellyfin-web
    libreoffice
    nextcloud-client
    nodejs_20 # TODO determine dynamic sourcing of Node
    obsidian
    pinentry-gnome3
    protonmail-desktop
    rpi-imager
    signal-desktop
    slack
    socat
    spotify
    tor
    veracrypt
    zoom-us
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
    ]
    ++ lib.optionals isWorkProfile workPkgs
    ++ lib.optionals isPersonalProfile personalPkgs
    ++ lib.optionals pkgs.stdenv.isLinux linuxPkgs
    ++ lib.optionals pkgs.stdenv.isDarwin [pkgs.yubikey-manager];

  services.syncthing.enable = isPersonalProfile;
}
