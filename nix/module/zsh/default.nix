{profile, ...}: {
  programs.zsh = {
    enable = true;
    shellAliases = {
      # Tmux Aliases
      tm = "tmux";
      ta = "tmux a";
      tat = "tmux a -t";
      tl = "tmux list-sessions";
      tx = "tmuxinator";

      tree = "tree -C -F -a -h --gitignore -I \".git\"";
    };

    initContent = ''
      # Functions
      scripts () {
        bat package.json | jq .scripts
      }

    '';

    profileExtra = ''
      if [[ $(uname) = "Darwin" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        source "/opt/homebrew/etc/profile.d/z.sh"
        export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
        # TODO move to npm module
        # Export NVM Paths
        export NVM_DIR="$HOME/.nvm"
        [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
        [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
      fi

      export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/local/share/npm/bin:$PATH

      # Preferred editor for local and remote sessions
      if [[ -n $SSH_CONNECTION ]]; then
        export EDITOR='vim'
      else
        export EDITOR='nvim'
      fi
    '';

    envExtra = ''
      # Source local zshenv if it exists
      [ -f ~/.zshenv.local ] && source ~/.zshenv.local
    '';

    sessionVariables = {
      DOCKER_HIDE_LEGACY_COMMANDS = true;
      DISABLE_AUTOUPDATER = true; # Handle Claude Code updates via Nix
      HOMEBREW_NO_AUTO_UPDATE = 1;
      NIX_PROFILE = "${profile}";
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
