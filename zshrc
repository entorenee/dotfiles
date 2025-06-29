source "/opt/homebrew/opt/spaceship/spaceship.zsh"
source "/opt/homebrew/etc/profile.d/z.sh"

# Export NVM Paths
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

export PATH=$HOME/bin:/usr/local/bin:/usr/local/share/npm/bin:$PATH
# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

export KUBECTL_PATH=/usr/local/bin/kubectl

# GPG Settings
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
gpg-connect-agent updatestartuptty /bye > /dev/null

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"
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

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# General Aliases
alias gu="git up"
# Git up is a separate package for better pull updates https://github.com/msiemens/PyGitUp

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
alias tx="tmuxinator"

# Git Alises
alias grb="git rebase"
alias grbd="git rebase develop"
alias gpb="git-prune-branches"

# Docker
export DOCKER_HIDE_LEGACY_COMMANDS=true

# Hub Aliases
alias hb="hub browse"
alias hpl="hub pr list"
alias hps="hub pr show"
alias hpc="hub pr checkout"

# Docker Compose Aliases
alias dc="docker compose"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcl="docker compose logs -f"
alias dce="docker compose ps --filter status=exited"

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

weather () {
  curl "https://wttr.in/$1?m"
}

dreload() {
  docker-compose stop "$1" && docker-compose rm -f "$1" && docker-compose up -d "$1" && docker-compose logs -f "$1"
}

git-prune-branches() {
        echo "switching to master or main branch.."
        git branch | grep 'main\|master' | xargs -n 1 git checkout
        echo "fetching with -p option...";
        git fetch -p;
        echo "running pruning of local branches"
        git branch -vv | grep ': gone]'|  grep -v "\*" | awk '{ print $1; }' | xargs -r git branch -D ;
}
