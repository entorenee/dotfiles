#!/usr/bin/env bash

read -p "Enter the SSH host [github.com]" host
host=${host:-github.com}
yubikey_pub=$HOME/.ssh/id_rsa_yubikey.pub

echo "Insert Yubikey with stored PGP keys."
read -p "Press enter to continue" </dev/tty

if [ -f $yubikey_pub ]; then
  echo "Yubikey SSH key already exists at $yubikey_pub. Not exporting file"
else
  ssh-add -L | grep "cardno:" > $yubikey_pub
  echo "Yubikey SSH key exported to $yubikey_pub"
fi

cat >> $HOME/.ssh/config << EOF
Host $host
  IdentitiesOnly yes
  IdentityFile $yubikey_pub
EOF

echo "SSH configuration set. Confirm public key is stored on $host for SSH access."
