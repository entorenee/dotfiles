# nixpkgs is still on git-up 2.3.0 (checked against master 2026-08-19), which
# fast-forwards branches by writing refs through GitPython and so bypasses
# git's "checked out at <worktree>" guard. Under worktrunk that silently
# desynchronized sibling worktrees. Upstream PR #145 rebases such branches
# through a real worktree instead and skips any with an operation in progress;
# it shipped in v2.5.0, hence this pin.
#
# Universal rather than a per-host opt-in: modules/home/git is base-tier, so
# every host above `minimal` consumes it.
#
# MAINTENANCE: drop this file once nixpkgs carries >= 2.5.0. Hash:
#   nix store prefetch-file mirror://pypi/g/git_up/git_up-<version>.tar.gz
_final: prev: {
  git-up = prev.git-up.overridePythonAttrs (old: {
    version = "2.5.0";

    src = prev.fetchPypi {
      pname = "git_up";
      version = "2.5.0";
      hash = "sha256-c0HbJMJ63RLMFqx84EjBqahR2UWwvk2KSPk8ixpp+D8=";
    };

    # 2.5.0 moved the build backend from poetry-core to hatchling.
    build-system = [prev.python3Packages.hatchling];

    # It also adds a `packaging` runtime dependency, and its `termcolor >= 3.2`
    # floor is already satisfied by nixpkgs, so the 2.3.0 relax entry is dead.
    pythonRelaxDeps = [];
    dependencies = old.dependencies ++ [prev.python3Packages.packaging];
  });
}
