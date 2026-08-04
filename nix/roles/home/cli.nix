{
  # Terminal workstation tooling, on top of the baseline. Everything a machine
  # that is actually developed on wants, whether or not it has a display.
  imports = [
    ./base.nix

    ../../modules/claude
    ../../modules/docker
    ../../modules/gh
    ../../modules/gh-dash
    ../../modules/lazygit
    ../../modules/navi
    ../../modules/npm
    ../../modules/nvm
    ../../modules/rtk
    ../../modules/smug
    ../../modules/tmux
    ../../modules/tmuxinator
    ../../modules/typos
    ../../modules/worktrunk
    ../../modules/yamlfmt
  ];
}
