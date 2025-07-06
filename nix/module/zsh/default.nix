{ ... }:
{
  programs.zsh = {
    enable = true;
    shellAliases = {
      # TODO move to npm module
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

      # TODO Move to docker module
      # Docker Compose Aliases
      dc = "docker compose";
      dcu = "docker compose up -d";
      dcd = "docker compose down";
      dcl = "docker compose logs -f";
      dce = "docker compose ps --filter status=exited";
    };

    initContent = ''
      # Functions
      scripts () {
        bat package.json | jq .scripts
      }

      # TODO: consider moving this to a bin script
      dreload() {
        docker-compose stop "$1" && docker-compose rm -f "$1" && docker-compose up -d "$1" && docker-compose logs -f "$1"
      }
    '';

    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
      source "/opt/homebrew/etc/profile.d/z.sh"

      # TODO move to npm module
      # Export NVM Paths
      export NVM_DIR="$HOME/.nvm"
      [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
      [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

      export PATH=$HOME/bin:/usr/local/bin:/usr/local/share/npm/bin:$PATH
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
