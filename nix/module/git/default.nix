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

      # TODO: consider moving this to a bin script
      git-prune-branches() {
        echo "switching to master or main branch.."
        git branch | grep 'main\|master' | xargs -n 1 git checkout
        echo "fetching with -p option...";
        git fetch -p;
        echo "running pruning of local branches"
        git branch -vv | grep ': gone]'|  grep -v "\*" | awk '{ print $1; }' | xargs -r git branch -D ;
      }
    '';
  };

  xdg.configFile."git".source = ./config;
}
