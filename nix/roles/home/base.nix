{
  # A machine on the network that I log into: the floor plus version control,
  # secrets, remote access, and the configured editor.
  #
  # This is no longer the bottom of the stack — minimal.nix is. The distinction
  # is network and state: everything added here assumes a remote to talk to
  # (git, ssh), a key to hold (gnupg), or a `~/dotfiles` checkout to reach
  # (bins, the nvim config). A host that cannot assume those takes minimal.nix
  # and adds what it wants.
  imports = [
    ./minimal.nix

    ../../modules/home/bins
    ../../modules/home/git
    ../../modules/home/gnupg
    ../../modules/home/nvim
    ../../modules/home/ssh
  ];
}
