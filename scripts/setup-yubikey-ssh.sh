#!/usr/bin/env bash

read -p "Enter the SSH host [github.com]" host
host=${host:-github.com}
ssh_dir="$HOME/.ssh"
yubikey_pub="$ssh_dir/id_rsa_yubikey.pub"

echo "SSH dir $ssh_dir"
echo "Insert Yubikey with stored PGP keys."
read -p "Press enter to continue" </dev/tty

if [ ! -d "$ssh_dir" ]; then
  echo "SSH directory doesn't exist. Creating it at $ssh_dir."
  mkdir -p $ssh_dir
  chmod 700 $ssh_dir
fi

if [ -f "$yubikey_pub" ]; then
  echo "Yubikey SSH key already exists at $yubikey_pub. Not exporting file"
else
  ssh-add -L | grep "cardno:" > $yubikey_pub
  chmod 600 $yubikey_pub
  echo "Yubikey SSH key exported to $yubikey_pub"
fi

cat >> $HOME/.ssh/config << EOF
Host $host
  IdentitiesOnly yes
  IdentityFile $yubikey_pub
EOF

echo "SSH configuration set. Confirm public key is stored on $host for SSH access."
