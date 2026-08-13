{...}: {
  programs.zsh = {
    enable = true;
    shellAliases = {
      # Tmux Aliases
      tm = "tmux";
      ta = "tmux a";
      tat = "tmux a -t";
      tl = "tmux list-sessions";
      tx = "tmuxinator";

      # Long builds on the hub must be rooted in a tmux server on the *hub*, not
      # on this laptop -- a laptop-side pane still loses its ssh connection on
      # sleep, and the build dies with the sshd session. Reattaches if present.
      hubb = "ssh -t hub 'tmux new -As build'";

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
      # Deduplicate XDG_DATA_DIRS for login shells. start-cosmic spawns one to
      # capture the environment and imports it into systemd, so duplicates from
      # hm-session-vars.sh + nix.sh would propagate to the whole COSMIC session.
      # Must run before start-cosmic reads the result.
      if [[ -n "$XDG_DATA_DIRS" ]]; then
        typeset -aU _xdg=("''${(@s/:/)XDG_DATA_DIRS}")
        export XDG_DATA_DIRS="''${(j/:/)_xdg}"
        unset _xdg
      fi

      if [[ $(uname) = "Darwin" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        source "/opt/homebrew/etc/profile.d/z.sh"
        # TODO move to npm module
        # Export NVM Paths
        export NVM_DIR="$HOME/.nvm"
        [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
        [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
      fi

      # pnpm global binaries. pnpm 10.x uses $PNPM_HOME itself as the global
      # bin dir, so it must be on PATH; the legacy $PNPM_HOME/bin entry is kept
      # for older shims (e.g. eas) installed under the previous layout.
      export PNPM_HOME="$HOME/.local/share/pnpm"

      export PATH=$HOME/bin:$HOME/.local/bin:$PNPM_HOME:$PNPM_HOME/bin:/usr/local/bin:/usr/local/share/npm/bin:$PATH

      # Preferred editor for local and remote sessions
      if [[ -n $SSH_CONNECTION ]]; then
        export EDITOR='vim'
      else
        export EDITOR='nvim'
      fi
    '';

    envExtra = ''
      [ -f ~/.zshenv.local ] && source ~/.zshenv.local
    '';

    sessionVariables = {
      DOCKER_HIDE_LEGACY_COMMANDS = "1";
      HOMEBREW_NO_AUTO_UPDATE = 1;
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
