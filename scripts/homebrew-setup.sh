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
  git-lfs
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
  tmuxinator
  tree
  wget
  ykman
  Z
)

PERSONAL_PACKAGES=(
  go
  hugo
  tor
)

WORK_PACKAGES=(
  doctl
  mkcert
  mysql
)

if [[ "$workspace" == "personal" ]]; then
  PACKAGES=("${BASE_PACKAGES[@]}" "${PERSONAL_PACKAGES[@]}")
else
  PACKAGES=("${BASE_PACKAGES[@]}" "${WORK_PACKAGES[@]}")
fi

echo "Installing packages..."
brew install ${PACKAGES[@]}

BASE_CASKS=(
  docker
  elgato-control-center
  font-sauce-code-pro-nerd-font
  firefox
  karabiner-elements
  iterm2
  rectangle
  vlc
  yubico-authenticator
)

PERSONAL_CASKS=(
  anylist
  backblaze
  balenaetcher
  calibre
  discord
  keepassxc
  nextcloud
  ollama
  proton-mail
  protonvpn
  raspberry-pi-imager
  signal
  slack
  tpvirtual
  veracrypt
  zoom
)

WORK_CASKS=(
  bitwarden
  tableplus
)

if [[ "$workspace" == "personal" ]]; then
  CASKS=("${BASE_CASKS[@]}" "${PERSONAL_CASKS[@]}")
else
  CASKS=("${BASE_CASKS[@]}" "${WORK_CASKS[@]}")
fi

echo "Installing cask apps..."
brew install --cask ${CASKS[@]}
echo "Homebrew setup complete"
