#!/usr/bin/env bash
# 
# Bootstrap script for setting up a new OSX machine
# 
# This should be idempotent so it can be run multiple times.

echo "Starting Mac bootstrapping"

echo "Configuring git"
git config --global user.email "26767995+entorenee@users.noreply.github.com"
git config --global user.name "Skyler Lemay"
git config --global commit.gpgsign true
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
touch ~/.ssh/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
echo "Git scaffolding complete"

# Check for Homebrew, install if we don't have it
if test ! $(which brew); then
    echo "Installing homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Update homebrew recipes
brew update

PACKAGES=(
  bat
  git
  git-lfs
  gh
  helm
  hub
  kubectl
  k9s
  jq
  minikube
  neovim
  node
  nvm
  python
  postgresql@14
  rcm
  ripgrep
  skaffold
  spaceship
  tmux
  tree
)

echo "Installing packages..."
brew install ${PACKAGES[@]}

CASKS=(
  1password
  docker
  firefox
  google-chrome
  karabiner-elements
  iterm2
  rectangle
  slack
)

echo "Installing cask apps..."
brew install --cask ${CASKS[@]}

# Install Python packages
echo "Installing Python packages"
pip3 install git-up

echo "Bootstrapping complete"
echo "Generate a ed25519 key for git usage. Reference https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent"
