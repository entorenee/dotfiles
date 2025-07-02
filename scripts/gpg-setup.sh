#!/usr/bin/env bash

echo "Initializing GPG. This only needs to be done once"
gpg -k

echo "Importing developer public keys"
gpg --import ./gpg-setup/*.asc

source ./scripts/setup-yubikey-ssh.sh
source ./scripts/set-git-signing-key.sh

echo "GPG setup is complete"
