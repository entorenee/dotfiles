{ ... }:
{
  programs.git = {
    enable = true;
  };

  programs.zsh = {
    shellAliases = {
      gpb = "git-prune-branches";
      grbd = "git rebase develop";
      grb = "git rebase";
      gu = "git up"; # Better git branch management
    };

    initContent = ''
      gpnew () {
        git push origin -u $(git rev-parse --abbrev-ref HEAD)
      }
    '';
  };

  xdg.configFile."git".source = ./config;
}
