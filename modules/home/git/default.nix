{ pkgs, ... }:
{
  home.packages = [ pkgs.git ];

  programs.zsh = {
    shellAliases = {
      gpb = "git-prune-branches";
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

      # Worktree-safe replacement for git-up. git-up fast-forwarded any branch
      # it did not consider "current" by writing the ref through GitPython,
      # which bypasses git's "checked out at <worktree>" guard. With worktrunk
      # that silently desynchronized sibling worktrees: their HEAD jumped to
      # origin while their index stayed on the old tree, so the just-pulled
      # commits showed up as staged changes there. The refspec form of
      # git fetch refuses those branches instead of corrupting them.
      gu () {
        git fetch --all --prune --quiet || return
        local cur up b
        cur=$(git symbolic-ref --quiet --short HEAD) || {
          print -u2 "gu: detached HEAD, not rebasing"
          return 1
        }
        if up=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null); then
          git rebase --autostash "$up" || return
        else
          print -u2 "gu: $cur has no upstream, skipping rebase"
        fi
        for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
          [[ $b == $cur ]] && continue
          up=$(git rev-parse --abbrev-ref --symbolic-full-name "$b@{u}" 2>/dev/null) || continue
          [[ $(git rev-parse "$b") == $(git rev-parse "$up") ]] && continue
          git merge-base --is-ancestor "$b" "$up" || continue
          if git fetch --quiet . "$up:$b" 2>/dev/null; then
            print "gu: fast-forwarded $b -> $up"
          else
            print "gu: skipped $b (checked out in another worktree)"
          fi
        done
      }
    '';
  };

  xdg.configFile."git".source = ./config;
}
