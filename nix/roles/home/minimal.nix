{...}: {
  # The floor: a usable shell and a working editor, and nothing else. Safe on an
  # airgapped or memory-constrained host — nothing here assumes a network, a
  # remote, or a `~/dotfiles` checkout.
  #
  # This is deliberately below base.nix rather than something base.nix subtracts
  # from. Opting out is the wrong primitive: `disabledModules` is built for
  # replacing a module with a fork (and fails silently-wrong if a role adds the
  # module back by another path), and per-module `enable` flags would put an
  # options block on every module to serve one appliance host. A host that needs
  # less than base takes this role and adds the specific modules it wants —
  # see docs/local/plans/nix-architecture-redesign.md §5.
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
  xdg.autostart.enable = true;

  # `targets.genericLinux` is deliberately absent. Upstream describes it as
  # "settings that make Home Manager work better on GNU/Linux distributions
  # other than NixOS", and a tier role cannot know which it is on — the
  # obvious `pkgs.stdenv.isLinux` reads true on NixOS too, which is how hub
  # ended up with /usr/share/ubuntu and Debian zsh fpaths on its PATH. It is
  # set in nix/lib/home.nix instead, where the distinction is structural.
}
