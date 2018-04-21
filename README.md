# Daniel Lemay dotfiles

## Setup

Feel free to clone or fork the repo and store the dotfiles in your **home** directory.
```
$ cd ~
$ git clone https://github.com/dslemay/dotfiles
```

### Install [RCM](https://github.com/thoughtbot/rcm)

This repo uses RCM to manage the dotfiles and relocate them from within the repo folder to your home directory.

1. Install RCM for your OS per the [RCM README](https://github.com/thoughtbot/rcm/blob/master/README.md).
2. After installing RCM run the command below. *Note: The configuration expects that you cloned your dotfiles to `~/dotfiles`. If you cloned to a different location the`rcrc` file must be updated.*

```
$ env RCRC=$HOME/dotfiles/rcrc rcup
```
RCM creates dotfile symlinks (`.vimrc` -> `/dotfiles/vimrc`) from your home directory to your `/dotfiles/` directory.

## Installing Vim Plugins

The vimrc file uses [Vim-plug](https://github.com/junegunn/vim-plug) for its plugin management. To install the plugins listed in the vimrc file:

1. Open Vim in a terminal. The vimrc file checks to see if Vim-Plug is already installed and installs it if it isn't.
2. Run `:PlugInstall` on the Vim Command line.

---
Many thanks to Francesco Renzi for his detailed [post](https://uracode.com/2017/08/05/the-perks-of-storing-your-dotfiles-in-a-repository/) on how to set up this system.
