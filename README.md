# Skyler Lemay dotfiles

## Setup

Feel free to clone or fork the repo and store the dotfiles in your **home** directory.
```
$ cd ~
$ git clone https://github.com/entorenee/dotfiles
```

## System configuration requirements

1. UltiSnips utilizes a build of Vim which includes Python. The default version installed on Mac OS is not compatible. If you do not want to use UltiSnips remove it from the vimrc file. Otherwise install Vim via homebrew by running `$ brew install vim`.
2. The vimrc currently sets nocompatible. This can create issues when using git commit and using the editor window to write your commit. By default Git uses vi, which has compatibility issues with UltiSnips. To resolve this, set your default Git editor to Vim by running the following command in your terminal. `$ git config --global core.editor "vim"`.

### Install [RCM](https://github.com/thoughtbot/rcm)

This repo uses RCM to manage the dotfiles and relocate them from within the repo folder to your home directory.

1. Install RCM for your OS per the [RCM README](https://github.com/thoughtbot/rcm/blob/master/README.md).
2. After installing RCM run the command below. *Note: The configuration expects that you cloned your dotfiles to `~/dotfiles`. If you cloned to a different location the`rcrc` file must be updated.*

```
$ env RCRC=$HOME/dotfiles/rcrc rcup -x scripts
```
RCM creates dotfile symlinks (`.vimrc` -> `/dotfiles/vimrc`) from your home directory to your `/dotfiles/` directory.

## Additional Installations

The following packages are generally used and not part of the scaffolding script.

## Oh My ZSH

- Install zsh via [Oh My ZSH](https://ohmyz.sh/#install)
- Install [spaceship theme](https://github.com/denysdovhan/spaceship-prompt#oh-my-zsh)
- Install [z.sh](https://github.com/rupa/z) for freecency search

## NVM

To utilize nvm for node version management, follow the [installation instructions](https://github.com/nvm-sh/nvm#install--update-script)

## Manual configuration

## Iterm

After copying the dotfiles, several pieces need to be manually set in Iterm's preferences.

- Set the preference backup to `~/dotfiles/iterm2`. Make sure to ignore local settings when first selecting this to avoid overwriting the settings.
- Set iTerm2 to save the settings on exit.
- The zsh theme uses Powerline fonts and will not render correctly without setting the display font to a Powerline based font. I currently use Dank Mono.

## Installing Vim Plugins

The vimrc file uses [Vim-plug](https://github.com/junegunn/vim-plug) for its plugin management. To install the plugins listed in the vimrc file:

1. Open Vim in a terminal. The vimrc file checks to see if Vim-Plug is already installed and installs it if it isn't.
2. Run `:PlugInstall` on the Vim Command line.

### Installing Conquer of Completion Language Servers

After installing Vim plugins, the following language servers may be installed and used for development.

- `:CocInstall coc-tsserver`: TypeScript language server
- `:CocInstall coc-rescript`: ReScript/ReasonML language server

Running `:CocList extensions` will list all language servers/extensions used by CoC.

---
Many thanks to Francesco Renzi for his detailed [post](https://uracode.com/2017/08/05/the-perks-of-storing-your-dotfiles-in-a-repository/) on how to set up this system.
