#!/usr/bin/env bash
# 
# Bootstrap script for setting up a new OSX machine
# 
# This should be idempotent so it can be run multiple times.

echo "Starting Mac bootstrapping"

# Check for Homebrew, install if we don't have it
if test ! $(which brew); then
    echo "Installing homebrew..."
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
fi

# Update homebrew recipes
brew update

PACKAGES=(
  bat
  git
  jq
  neovim
  node
  rcm
  tmux
  tree
)

echo "Installing packages..."
brew install ${PACKAGES[@]}

CASKS=(
  1password
  bartender
  firefox
  focus
  google-chrome
  iterm2
  slack
)

echo "Installing cask apps..."
brew install ${CASKS[@]}

echo "Bootstrapping complete"
