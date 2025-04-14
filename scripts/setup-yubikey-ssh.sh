#!/usr/bin/env bash

read -p "Enter the SSH host [github.com]" host
host=${host:-github.com}
ssh_config=$(
cat <<EOF
Host $host
  IdentitiesOnly yes
  IdentityFile ~/.ssh/id_rsa_yubikey.pub
EOF
)
select key_import in yes no; do
  case $key_import in
    yes)
      echo "Insert Yubikey with stored PGP keys."
      read -p "Press enter to continue" </dev/tty
      ssh-add -L | grep "cardno:" > ~/.ssh/id_rsa_yubikey.pub
      cat $ssh_config >> $HOME/.ssh/config
      echo "Yubikey SSH key added. Confirm public key is configured in GitHub for SSH access."
      break;;
    no)
      break;;
  esac
done
