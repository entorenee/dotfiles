# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Export NVM Paths
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
export PATH=$HOME/bin:/usr/local/bin:/usr/local/share/npm/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

export PATH=$HOME/bin:/usr/local/bin:/usr/local/share/npm/bin:$PATH

. /usr/local/etc/profile.d/z.sh

NVM_LAZY=1

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="spaceship"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Disable globbing patterns with git commands. OhMyZSH enables globbing by default
# https://github.com/ohmyzsh/ohmyzsh/issues/4398#issuecomment-143335160
alias git="noglob git"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
plugins=(
  git
  nvm
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# General Aliases
alias gu="git up"
# Git up is a separate package for better pull updates https://github.com/msiemens/PyGitUp

# Yarn Aliases
alias y="yarn"
alias yt="yarn test"
alias ytw="yarn test --watch"
alias ytc="yarn test --coverage"
alias ya="yarn add"
alias yad="yarn add --dev"
alias yr="yarn run"

# NPM Aliases
alias n="npm"
alias ni="npm install"
alias nis="npm install --save"
alias nid="npm install --save-dev"
alias ns="npm start"
alias nr="npm run"
alias nt="npm test"

# Tmux Aliases
alias tm="tmux"
alias tma="tmux a"
alias tmat="tmux a -t"

# Git Alises
alias grb="git rebase"
alias grbd="git rebase develop"

# Docker
export DOCKER_HIDE_LEGACY_COMMANDS=true

# Hub Aliases
alias hb="hub browse"
alias hpl="hub pr list"
alias hps="hub pr show"
alias hpc="hub pr checkout"

# Docker Compose Aliases
alias dc="docker-compose"
alias dcu="docker-compose up -d"
alias dcd="docker-compose down"
alias dcl="docker-compose logs -f"

alias awsdev="aws-vault exec engineer-dev --"
alias awsv="aws-vault exec engineer-prod --"

# Functions
vlist () {
  nvim -p $(rg -l "$1")
}
gpnew () {
  git push origin -u $(git rev-parse --abbrev-ref HEAD)
}
code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}
scripts () {
  bat package.json | jq .scripts
}
marked () {
  open -a Marked\ 2 "$1"
}
weather () {
  curl "https://wttr.in/$1?m"
}
dreload() {
  docker-compose stop "$1" && docker-compose rm -f "$1" && docker-compose up -d "$1" && docker-compose logs -f "$1"
}
