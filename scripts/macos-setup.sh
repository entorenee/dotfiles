#!/usr/bin/env bash
# 
# Bootstrap script for setting up a new OSX machine
# 
# This should be idempotent so it can be run multiple times.

echo "Starting Mac bootstrapping"

echo "Installing Oh My ZSH"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "Configuring git"
git config --global user.email "26767995+entorenee@users.noreply.github.com"
git config --global user.name "Skyler Lemay"
git config --global commit.gpgsign true
git config --global tag.gpgsign true
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
  gnupg
  helm
  hub
  kubectl
  k9s
  jq
  minikube
  neovim
  node
  nvm
  obsidian
  pinentry
  pinentry-mac
  pygitup
  python
  postgresql@14
  rcm
  ripgrep
  skaffold
  spaceship
  tmux
  tree
  wget
  ykman
)

echo "Installing packages..."
brew install ${PACKAGES[@]}

CASKS=(
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

echo "Scaffolding out npm"
cat >> $NVM_DIR/default-packages<< EOF
npm-check-updates
EOF
nvm install --lts

echo "Bootstrapping complete"
