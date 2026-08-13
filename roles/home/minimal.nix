{...}: {
  # The floor: a usable shell and a working editor, and nothing else. Safe on an
  # airgapped or memory-constrained host — nothing here assumes a network, a
  # remote, or a `~/dotfiles` checkout.
  imports = [
    ../../modules/options.nix

    ../../modules/home/minimal-pkgs.nix
    ../../modules/home/nvim/package.nix
    ../../modules/home/starship
    ../../modules/home/zsh
  ];

  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
  xdg.enable = true;

  # `xdg.autostart` is deliberately absent: a headless board has no session to
  # autostart into.

  # `targets.genericLinux` is deliberately absent: it applies only to non-NixOS
  # Linux, and `pkgs.stdenv.isLinux` reads true on NixOS too, so gating on it
  # here would put Debian/Ubuntu paths on a NixOS host's PATH. Set in
  # lib/home.nix instead, where the distinction is structural.
}
