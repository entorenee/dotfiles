#!/usr/bin/env bash

echo "Do you want to set the git signing key?"
select opt in yes no; do
  case $opt in
    yes)
      echo "If you are using a subkey, include a ! at the end of the id"
      read -p "Enter signing key id" key_id
      git config --global user.signingkey $key_id
      break;;
    no)
      break;;
  esac
done
