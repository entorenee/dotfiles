{ ... }:
{
  programs.tmux.tmuxinator = {
    enable = true;
  };
  xdg.configFile."tmuxinator".source = ./projects;
}
