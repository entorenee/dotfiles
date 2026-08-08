{...}: {
  # The floor: a usable shell and a working editor, and nothing else. Safe on an
  # airgapped or memory-constrained host — nothing here assumes a network, a
  # remote, or a `~/dotfiles` checkout.
  #
  # This is deliberately a tier below base.nix rather than something base.nix
  # subtracts from. Opting out is the wrong primitive: `disabledModules` is for
  # replacing a module with a fork, and fails silently-wrong if another role
  # adds the module back by a different path; per-module `enable` flags would
  # put an options block on every module to serve one appliance host. A host
  # that needs less than base takes this role and adds the specific modules it
  # wants — see CONVENTIONS.md.
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
  # Linux, and a tier role cannot know which it is on. `pkgs.stdenv.isLinux`
  # reads true on NixOS too, which puts Debian/Ubuntu paths on a NixOS host's
  # PATH. It is set in lib/home.nix instead, where the distinction is
  # structural.
}
