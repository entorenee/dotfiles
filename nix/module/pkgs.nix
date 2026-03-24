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
    arduino-ide
    calibre
    cryptsetup # TODO: Confirm if this is a needed dependency
    cspell
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
      # yubikey-manager TODO only apply this to Mac. Nix and Pop OS run into a pcscd protocol mismatch
    ]
    ++ lib.optionals isWorkProfile workPkgs
    ++ lib.optionals isPersonalProfile personalPkgs
    ++ lib.optionals pkgs.stdenv.isLinux linuxPkgs;

  services.syncthing.enable = isPersonalProfile;
}
