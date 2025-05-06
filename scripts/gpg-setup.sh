#!/usr/bin/env bash

agents_dir="$HOME/Library/LaunchAgents"

echo "Initializing GPG. This only needs to be done once"
gpg -k

if [ ! -d "agents_dir" ]; then
  echo "$agents_dir does not exist. Creating it."
  mkdir -p $agents_dir
fi

# Add additional plist files
echo "Adding GPG launch agents"
cp ./gpg-setup/gnupg.gpg-agent.plist "$agents_dir"
launchctl load "$agents_dir/gnupg.gpg-agent.plist"

cp ./gpg-setup/gnupg.gpg-agent-symlink.plist "$agents_dir"
launchctl load "$agents_dir/gnupg.gpg-agent-symlink.plist"

echo "Restarting GPG Agent"
gpgconf --kill gpg-agent

echo "Importing developer public keys"
gpg --import ./gpg-setup/*.asc

source ./scripts/setup-yubikey-ssh.sh
source ./scripts/set-git-signing-key.sh

echo "GPG setup is complete"
