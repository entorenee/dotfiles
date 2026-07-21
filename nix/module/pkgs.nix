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
    caffeine-ng
    calibre
    cryptsetup # TODO: Confirm if this is a needed dependency
    docker
    docker-compose
    freefilesync
    insomnia
    jellyfin-desktop
    libreoffice
    nextcloud-client
    nodejs_22 # TODO determine dynamic sourcing of Node
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
    overlays = [
      (_final: prev: {
        protonmail-desktop = prev.protonmail-desktop.overrideAttrs (old: {
          postInstall =
            (old.postInstall or "")
            + ''
              echo "StartupWMClass=proton-mail" >> $out/share/applications/proton-mail.desktop
            '';
        });

        # Pin pnpm to the EXACT version fw_monorepo's package.json declares in
        # its `packageManager` field (pnpm@10.33.0). pnpm's version manager
        # compares the running binary against that pin; on any mismatch it
        # re-downloads AND signature-verifies the pinned build from the npm
        # registry on every command. That verification fetch fails inside
        # Claude Code's network sandbox and hard-aborts with "npm registry
        # signature could not be verified". Matching the version exactly means
        # no switch, no fetch, no failure. A nearby 10.x (nixpkgs pnpm_10 is
        # 10.34.5) does NOT work — the pin is exact.
        #
        # MAINTENANCE: bump both fields together whenever fw_monorepo changes
        # its packageManager pin. Get the hash with:
        #   nix store prefetch-file https://registry.npmjs.org/pnpm/-/pnpm-<version>.tgz
        pnpm = prev.pnpm_10.override {
          version = "10.33.0";
          hash = "sha256-v8wby60nmxOlFsRGp1s8WLaQS0XVehlRQRAV5Qt1GoA=";
        };
      })
    ];
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
      pnpm
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

  # proton-mail.png is actually SVG content; placing it in hicolor/scalable lets
  # GNOME find it reliably (pixmaps/ is not consistently searched from Nix profiles).
  home.file.".local/share/icons/hicolor/scalable/apps/proton-mail.svg" = lib.mkIf pkgs.stdenv.isLinux {
    source = "${pkgs.protonmail-desktop}/share/pixmaps/proton-mail.png";
  };

  services.syncthing.enable = isPersonalProfile;
}
