#!/usr/bin/env bash

read -p "Enter the SSH host [github.com]" host
host=${host:-github.com}

echo "Insert Yubikey with stored PGP keys."
read -p "Press enter to continue" </dev/tty
ssh-add -L | grep "cardno:" > ~/.ssh/id_rsa_yubikey.pub
cat >> $HOME/.ssh/config << EOF
Host $host
  IdentitiesOnly yes
  IdentityFile ~/.ssh/id_rsa_yubikey.pub
EOF

echo "Yubikey SSH key added. Confirm public key is stored on $host for SSH access."
