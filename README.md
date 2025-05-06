# Skyler Lemay dotfiles

This repository contains dotfiles shared across multiple computer systems, differentiating between work and personal profiles in terms of package installation and configuration. Under the hood it uses [rcm](https://github.com/thoughtbot/rcm) to sync the files from this directory to the home directory.

Most files are public and can be shared across systems. Some files are private and are consequently encrypted with the unencrypted versions placed in gitignore. This may be due to licensing restrictions, paid products including fonts, or sensitive/confidential information. These files are encrypted using GPG with the respective public keys of one or more of my profiles. They will not be accessible to others using the repository.

This configuration is highly opinionated and tailored to my preferences. Various aspects of it can be broken out into separate flows and scripts. This is not a plug and play solution for other engineers, though aspects of it may be used and adjusted to fit your needs. Strong preferences include:

* The use of Oh my ZSH for shell configuration
* The use of Homebrew for package management whenever possible
* A strong preference for assymetric encryption utilizing GPG for encryption, signing, and authentication
* The use of Yubikey as a hardware security key eliminating the storage of private keys on a networked computer
* The use of Neovim and Vimplugged as a code editor solution

## Setup

Feel free to clone or fork the repo and store the dotfiles in your **home** directory.
```
$ cd ~
$ git clone https://github.com/entorenee/dotfiles
```

Set the workspace type with `make set-workspace-type`. Many other scripts require this environment to be set in order to proceed. If you are working in multiple terminals, you will need to start a fresh terminal instance to resource the env file. The environment variable is exported in the shell session where the script is initially run.

Run `make initialize-mac` to scaffold out a number of the packages, configuration, and install rcm to manage the dotfiles.

To begin syncing the dotfiles to your home folder, run the command below. **NOTE:** Explicitly providing the RCRC environment variable is only needed on the first run. Once it is synchronized into the home folder, the default variable path will work

```
RCRC=~/dotfiles/rcrc rcup [-t work|personal]
```

Most of the dotfiles are shared. The `-t` flag allows you to install specific configuration files located within the respected `tag-$workspace` folders. The `-t` flag is optional.


## Optional scripts and configuration

Again, this is an opinionated setup prioritizing the use of GPG and Yubikeys. The following scripts are optional, but can be used to configure GPG, SSH authentication, and git signing.

### GPG setup

Running `make gpg-setup` will add GPG specific launch agents, as well as attempt to setup Yubikey SSH and git signing. This is a one time operation. Future operations to set up Yubikey SSH or git signing can be run with sepearate scripts.

### SSH Setup

Running `make setup-yubikey-ssh` will configure SSH to use the Yubikey for authentication. This also includes exporting the public key to the SSH folder if it is not already present.

The script also asks for a corresponding hostname to be added to the SSH config file. This will be added to the SSH config and list the Yubikey as the authentication method.

This script can be run multiple times to add additional hostnames to the SSH config. Do not forget to add the public key to the remote server for proper authentication.

### Git signing

Cryptographically signed commits provide validaty to the commit and the author. This provides greater confidence that the author is who they say they are. Again, my opinionated approach is that this should be done with an external key to protect the private key. The script supports a singular private key. My opinion is to have an offline certifying key and to use subkeys that expire for signing, encryption, and authentication. If using a subkey, append a `!` to the corresponding subkey id in the script. If using a singular key, this should be omitted.

For more information on how to securely generate a private key including airlocked machines, pleaase reference this extensive [Yubikey Guide](https://github.com/drduh/YubiKey-Guide) which details key generation, back up, and transfering the key to a Yubikey. My personal approach is highly informed by this guide.

### Manual configuration

## Iterm

After copying the dotfiles, several pieces need to be manually set in Iterm's preferences.

- Set the preference backup to `~/dotfiles/iterm2`. Make sure to ignore local settings when first selecting this to avoid overwriting the settings.
- Set iTerm2 to save the settings on exit.
- The zsh theme uses Powerline fonts and will not render correctly without setting the display font to a Powerline based font. I currently use Dank Mono.

### Installing Vim Plugins

The vimrc file uses [Vim-plug](https://github.com/junegunn/vim-plug) for its plugin management. To install the plugins listed in the vimrc file:

1. Open Vim in a terminal. The vimrc file checks to see if Vim-Plug is already installed and installs it if it isn't.
2. Run `:PlugInstall` on the Vim Command line.
