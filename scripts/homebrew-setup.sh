#!/usr/bin/env bash

source ./scripts/helpers.sh
# Validate workspace configuration and exit if invalid
check_workspace_and_exit

# Check for Homebrew, install if we don't have it
if test ! $(which brew); then
    echo "Installing homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Update homebrew recipes
brew update

BASE_PACKAGES=(
  bat
  git
  gh
  gnupg
  hub
  jq
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
  spaceship
  tmux
  tree
  wget
  ykman
)

WORK_PACKAGES=(
  git-lfs
  helm
  kubectl
  k9s
  minikube
  skaffold
)

if [[ "$workspace" == "personal" ]]; then
  PACKAGES=("${BASE_PACKAGES[@]}")
else
  PACKAGES=("${BASE_PACKAGES[@]}" "${WORK_PACKAGES[@]}")
fi

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
echo "Homebrew setup complete"
