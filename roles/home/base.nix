{
  # A machine on the network that I log into: the floor plus version control,
  # secrets, remote access, and the configured editor.
  #
  # What belongs here is decided by what a module assumes when it *runs*, not
  # what it needs to deploy: a remote to talk to (git, ssh), a key to hold
  # (gnupg), a `~/dotfiles` checkout to drive (bins), or a network to fetch from
  # (the nvim config bootstraps lazy.nvim from GitHub). A module that exists only
  # to serve a sibling here counts too: formatters and yamlfmt supply the
  # binaries nvim's conform config names, so they are useless below this tier.
  imports = [
    ./minimal.nix

    ../../modules/home/bins
    ../../modules/home/formatters
    ../../modules/home/git
    ../../modules/home/gnupg
    ../../modules/home/nvim
    ../../modules/home/ssh
    ../../modules/home/yamlfmt
  ];
}
