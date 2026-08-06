{
  # Terminal workstation tooling, on top of the baseline. Everything a machine
  # that is actually developed on wants, whether or not it has a display.
  imports = [
    ./base.nix

    ../../modules/home/cli-pkgs.nix
    ../../modules/home/claude
    ../../modules/home/docker
    ../../modules/home/gh
    ../../modules/home/gh-dash
    ../../modules/home/lazygit
    ../../modules/home/navi
    ../../modules/home/npm
    ../../modules/home/nvm
    ../../modules/home/rtk
    ../../modules/home/smug
    ../../modules/home/tmux
    ../../modules/home/tmuxinator
    ../../modules/home/typos
    ../../modules/home/worktrunk
    ../../modules/home/yamlfmt
  ];
}
