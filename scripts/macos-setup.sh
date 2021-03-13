#!/usr/bin/env bash
# 
# Bootstrap script for setting up a new OSX machine
# 
# This should be idempotent so it can be run multiple times.

echo "Starting Mac bootstrapping"

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
  hub
  jq
  neovim
  node
  nvm
  python
  rcm
  ripgrep
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
