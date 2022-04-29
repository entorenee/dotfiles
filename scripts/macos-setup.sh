#!/usr/bin/env bash
# 
# Bootstrap script for setting up a new OSX machine
# 
# This should be idempotent so it can be run multiple times.

echo "Starting Mac bootstrapping"

echo "Configuring git"
git config --global user.email "26767995+dslemay@users.noreply.github.com"
git config --global user.name "Skyler Lemay"

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
  gh
  helm
  hub
  kubectl
  jq
  minikube
  neovim
  node
  nvm
  python
  rcm
  ripgrep
  skaffold
  tmux
  tree
)

echo "Installing packages..."
brew install ${PACKAGES[@]}

CASKS=(
  1password
  bartender
  docker
  firefox
  focus
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
