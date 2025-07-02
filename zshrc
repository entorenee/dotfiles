# GPG Settings
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
gpg-connect-agent updatestartuptty /bye > /dev/null

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

# NPM Aliases & Functions
alias n="npm"
alias ni="npm install"
alias nis="npm install --save"
alias nid="npm install --save-dev"
alias ns="npm start"
alias nr="npm run"
alias nt="npm test"

scripts () {
  bat package.json | jq .scripts
}

# Tmux Aliases
alias tm="tmux"
alias tma="tmux a"
alias tmat="tmux a -t"
alias tx="tmuxinator"

# Git Alises
alias gu="git up" # Better git branch management
alias grb="git rebase"
alias grbd="git rebase develop"
alias gpb="git-prune-branches"

# Hub Aliases
alias hb="hub browse"
alias hpl="hub pr list"
alias hps="hub pr show"
alias hpc="hub pr checkout"

gpnew () {
  git push origin -u $(git rev-parse --abbrev-ref HEAD)
}

git-prune-branches() {
  echo "switching to master or main branch.."
  git branch | grep 'main\|master' | xargs -n 1 git checkout
  echo "fetching with -p option...";
  git fetch -p;
  echo "running pruning of local branches"
  git branch -vv | grep ': gone]'|  grep -v "\*" | awk '{ print $1; }' | xargs -r git branch -D ;
}

# Docker
export DOCKER_HIDE_LEGACY_COMMANDS=true

# Docker Compose Aliases and Functions
alias dc="docker compose"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcl="docker compose logs -f"
alias dce="docker compose ps --filter status=exited"

dreload() {
  docker-compose stop "$1" && docker-compose rm -f "$1" && docker-compose up -d "$1" && docker-compose logs -f "$1"
}

# Functions
vlist () {
  nvim -p $(rg -l "$1")
}

code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}
