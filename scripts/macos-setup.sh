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

# Install and configure Homebrew
source ./scripts/homebrew-setup.sh

echo "Configuring git"

if [[ "$workspace" == "personal" ]]; then
  git_email="26767995+entorenee@users.noreply.github.com"
else
  echo "Configure work email"
  git_email="skyler@freeworld.org"
fi
git config --global user.email $git_email
git config --global user.name "Skyler Lemay"
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global init.defaultBranch main

echo "Installing GitHub Extensions"
gh extension install dlvhdr/gh-dash
echo "Git scaffolding complete"

echo "Scaffolding out npm"
mkdir -p ~/.nvm
cat >> $NVM_DIR/default-packages<< EOF
npm-check-updates
EOF
nvm install --lts
nvm alias default 'lts/*'

echo "Bootstrapping complete"
