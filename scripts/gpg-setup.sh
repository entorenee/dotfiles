#!/usr/bin/env bash

echo "Initializing GPG. This only needs to be done once"
gpg -k

# Add additional plist files
echo "Adding GPG launch agents"
cp ../gpg-setup/gnupg.gpg-agent.plist $HOME/Library/LaunchAgents
launchctl load $HOME/Library/LaunchAgents/gnupg.gpg-agent.plist

cp ../gpg-setup/gnupg.gpg-agent-symlink.plist $HOME/Library/LaunchAgents
launchctl load $HOME/Library/LaunchAgents/gnupg.gpg-agent-symlink.plist

echo "Restarting GPG Agent"
gpgconf --kill gpg-agent

echo "Importing developer public keys"
gpg --import ../gpg-setup/*.asc

./setup-yubikey-ssh.sh
./set-git-signing-key.sh

echo "GPG setup is complete"
