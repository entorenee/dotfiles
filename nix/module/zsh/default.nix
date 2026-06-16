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
      # Deduplicate XDG_DATA_DIRS for non-login interactive shells (terminals).
      # hm-session-vars.sh and nix.sh both prepend/append nix paths; without
      # this, opening a terminal after COSMIC session startup produces 3× copies.
      if [[ -n "$XDG_DATA_DIRS" ]]; then
        typeset -aU _xdg=("''${(@s/:/)XDG_DATA_DIRS}")
        export XDG_DATA_DIRS="''${(j/:/)_xdg}"
        unset _xdg
      fi

      # Functions
      scripts () {
        bat package.json | jq .scripts
      }

    '';

    profileExtra = ''
      # Deduplicate XDG_DATA_DIRS for login shells.
      # start-cosmic spawns a login shell to capture the user environment and
      # then imports all changed vars into systemd via import-environment.
      # hm-session-vars.sh (.zprofile) + nix.sh (sourced from it) both add nix
      # paths, creating 2× duplicates that get pushed into the entire COSMIC
      # session. Dedup here before start-cosmic imports the result to systemd.
      if [[ -n "$XDG_DATA_DIRS" ]]; then
        typeset -aU _xdg=("''${(@s/:/)XDG_DATA_DIRS}")
        export XDG_DATA_DIRS="''${(j/:/)_xdg}"
        unset _xdg
      fi

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

      # pnpm global binaries (global bin dir is $PNPM_HOME/bin, not $PNPM_HOME)
      export PNPM_HOME="$HOME/.local/share/pnpm"

      export PATH=$HOME/bin:$HOME/.local/bin:$PNPM_HOME/bin:/usr/local/bin:/usr/local/share/npm/bin:$PATH

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
      DOCKER_HIDE_LEGACY_COMMANDS = "1";
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
