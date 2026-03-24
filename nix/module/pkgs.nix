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
    discord
    docker
    docker-compose
    freefilesync
    insomnia
    jellyfin-web
    keepassxc
    libreoffice
    nextcloud-client
    nodejs_20 # TODO determine dynamic sourcing of Node
    obsidian
    pinentry-gnome3
    protonmail-desktop
    protonvpn-gui
    signal-desktop
    slack
    syncthing # TODO: confirm if this can be set up in Home Manager
    spotify
    tor
    veracrypt # TODO see if this still applies of switch to luks
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
