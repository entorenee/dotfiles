#!/usr/bin/env bash

source ./scripts/helpers.sh
# Validate workspace configuration and exit if invalid
check_workspace_and_exit

# Check for Homebrew, install if we don't have it
if test ! $(which brew); then
    echo "Installing homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Update homebrew
brew update

BASE_PACKAGES=(
  bat
  git
  gh
  gnupg
  htop
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
  Z
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

BASE_CASKS=(
  docker
  firefox
  google-chrome
  karabiner-elements
  iterm2
  rectangle
  yubico-authenticator
)

PERSONAL_CASKS=(
  anylist
  backblaze
  balenaetcher
  calibre
  discord
  proton-mail
  proton-pass
  raspberry-pi-imager
  signal
  slack
  veracrypt
  zoom
)

WORK_CASKS=(
  cursor
)

if [[ "$workspace" == "personal" ]]; then
  PACKAGES=("${BASE_CASKS[@]}")
else
  PACKAGES=("${BASE_CASKS[@]}" "${WORK_CASKS[@]}")
fi

echo "Installing cask apps..."
brew install --cask ${CASKS[@]}
echo "Homebrew setup complete"
