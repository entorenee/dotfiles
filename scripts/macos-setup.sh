#!/usr/bin/env bash
# 
# Bootstrap script for setting up a new OSX machine
# 
# This should be idempotent so it can be run multiple times.

workspace=${WORKSPACE_TYPE}
found=false
VALID_WORKSPACES=(
	personal
	work
)
for item in "${VALID_WORKSPACES[@]}"; do
  if [[ "$item" == "$workspace" ]]; then
    found=true
    break
  fi
done

if [ ! -z "$workspace" ]; then
  if ! $found; then
    echo "Workspace value ${workspace} is invalid. Unsetting value."
    workspace=""
  else
    echo "Workspace is valid. Current value is $workspace. Do you want to continue with this value?"
    select continue in yes no; do
      case $continue in
        yes)
          echo "Continuing with $workspace configuration"
          break;;
        no)
          echo "Unsetting workspace value"
          workspace=""
          break;;
      esac
    done
  fi
fi

if [ -z "$workspace" ]; then
  echo "Please select workspace type"
  select workspace in "${VALID_WORKSPACES[@]}"; do
    echo "Selected option $workspace"
    exit 0;
  done
fi

echo "Starting Mac bootstrapping"

if [ -z "$ZSH" ]; then
  echo "Installing Oh My ZSH"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "ZSH already installed. Skipping install"
fi

# Persist workspace to shell env
echo "Persisting workspace to the environment"
cat >> $HOME/.zshev<< EOF
export WORKSPACE_TYPE=$workspace
source $HOME/.zshrc
EOF

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

if [[ "$workspace" == "personal" ]]; then
  git_email="26767995+entorenee@users.noreply.github.com"
else
  git_email="skyler.lemayhingehealth.com"
fi

echo "Configuring git"
git config --global user.email $git_email
git config --global user.name "Skyler Lemay"
git config --global commit.gpgsign true
git config --global tag.gpgsign true
echo "Git scaffolding complete"

echo "Scaffolding out npm"
cat >> $NVM_DIR/default-packages<< EOF
npm-check-updates
EOF
nvm install --lts
nvm alias default lts/*

echo "Bootstrapping complete"
