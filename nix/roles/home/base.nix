{pkgs, ...}: {
  # The irreducible home-manager baseline: shell, editor, VCS, secrets.
  # Everything here must be safe on a headless, resource-constrained host.
  imports = [
    ../../modules/options.nix

    ../../modules/home/bins
    ../../modules/home/git
    ../../modules/home/gnupg
    ../../modules/home/nvim
    ../../modules/home/pkgs.nix
    ../../modules/home/ssh
    ../../modules/home/starship
    ../../modules/home/zsh
  ];

  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
  xdg.enable = true;
  xdg.autostart.enable = true;
  targets.genericLinux.enable = pkgs.stdenv.isLinux;
}
