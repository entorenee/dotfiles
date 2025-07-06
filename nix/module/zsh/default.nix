{ ... }:
{
  programs.zsh = {
    enable = true;
    shellAliases = {
      # NPM aliases
      ni = "npm install";
      nis = "npm install --save";
      nid = "npm install --save-dev";
      ns = "npm start";
      nr = "npm run";
      nt = "npm test";

      # Tmux Aliases
      tm = "tmux";
      ta = "tmux a";
      tat = "tmux a -t";
      tl = "tmux list-sessions";
      tx = "tmuxinator";

      # Git Alises
      gu = "git up"; # Better git branch management
      grb = "git rebase";
      grbd = "git rebase develop";
      gpb = "git-prune-branches";

      # Docker Compose Aliases
      dc = "docker compose";
      dcu = "docker compose up -d";
      dcd = "docker compose down";
      dcl = "docker compose logs -f";
      dce = "docker compose ps --filter status=exited";
    };

    initContent = ''
      scripts () {
        bat package.json | jq .scripts
      }

      gpnew () {
        git push origin -u $(git rev-parse --abbrev-ref HEAD)
      }

      # TODO: consider moving this to a bin script
      git-prune-branches() {
        echo "switching to master or main branch.."
        git branch | grep 'main\|master' | xargs -n 1 git checkout
        echo "fetching with -p option...";
        git fetch -p;
        echo "running pruning of local branches"
        git branch -vv | grep ': gone]'|  grep -v "\*" | awk '{ print $1; }' | xargs -r git branch -D ;
      }

      # TODO: consider moving this to a bin script
      dreload() {
        docker-compose stop "$1" && docker-compose rm -f "$1" && docker-compose up -d "$1" && docker-compose logs -f "$1"
      }

      vlist () {
        nvim -p $(rg -l "$1")
      }
    '';

    sessionVariables = {
      DOCKER_HIDE_LEGACY_COMMANDS = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "nvm"
      ];
    };
  };
}
