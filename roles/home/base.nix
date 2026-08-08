{
  # A machine on the network that I log into: the floor plus version control,
  # secrets, remote access, and the configured editor.
  #
  # minimal.nix is the bottom of the stack, not this. The distinction is what
  # these modules assume when they *run*, not what they need to deploy: a remote
  # to talk to (git, ssh), a key to hold (gnupg), a `~/dotfiles` checkout to
  # drive (the bins scripts rebuild and flake-update it), or a network to fetch
  # from (the nvim config bootstraps LazyVim from GitHub). A host that cannot
  # assume those takes minimal.nix and adds what it wants.
  imports = [
    ./minimal.nix

    ../../modules/home/bins
    ../../modules/home/git
    ../../modules/home/gnupg
    ../../modules/home/nvim
    ../../modules/home/ssh
  ];
}
