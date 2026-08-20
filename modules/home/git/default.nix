{ pkgs, ... }:
{
  home.packages = [
    pkgs.git
    pkgs.git-up
  ];

  programs.zsh = {
    shellAliases = {
      gpb = "git-prune-branches";
      gu = "git up"; # Better git branch management
      grbd = "git rebase develop";
      grb = "git rebase";
      # Safe force-push: refuses if remote moved (lease) or if local is
      # missing anything from the latest fetch (if-includes). Overrides
      # oh-my-zsh's plain --force-with-lease gpf.
      gpf = "git push --force-with-lease --force-if-includes";
    };

    initContent = ''
      gpnew () {
        git push origin -u $(git rev-parse --abbrev-ref HEAD)
      }
    '';
  };

  xdg.configFile."git".source = ./config;
}
