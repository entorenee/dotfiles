{
  # A machine on the network that I log into: the floor plus version control,
  # secrets, remote access, and the configured editor.
  #
  # What belongs here is decided by what a module assumes when it *runs*, not
  # what it needs to deploy: a remote to talk to (git, ssh), a key to hold
  # (gnupg), a `~/dotfiles` checkout to drive (bins), or a network to fetch from
  # (the nvim config bootstraps LazyVim from GitHub).
  imports = [
    ./minimal.nix

    ../../modules/home/bins
    ../../modules/home/git
    ../../modules/home/gnupg
    ../../modules/home/nvim
    ../../modules/home/ssh
  ];
}
