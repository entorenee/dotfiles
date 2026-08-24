{
  config,
  ...
}: let
  # Absolute, not `~/…`: a JSON settings value is literal and would not expand.
  frictionRoot = "${config.home.homeDirectory}/claude-friction";
in {
  programs.claude-code.settings = {
    env.MY_CLAUDE_FRICTION_ROOT = frictionRoot;
    # Outside the artifacts tree, so it needs grants of its own — the sandbox
    # reaches no path that is not named here.
    sandbox.filesystem.allowRead = [frictionRoot];
    sandbox.filesystem.allowWrite = [frictionRoot];
  };

  # Duplicated from settings.env deliberately, as artifactsRoot is: the path has
  # to resolve in a plain shell and not only inside a Claude session.
  home.sessionVariables.MY_CLAUDE_FRICTION_ROOT = frictionRoot;

  # The log is a notepad, so nothing gates an entry at write time. The skills
  # write the file and stop; this commits and pushes it. Letting the daemon own
  # the commit is also what keeps `Bash(git commit*)`/`Bash(git add*)` in
  # `permissions.deny` untouched — Claude never runs git in this repo at all.
  services.git-sync = {
    enable = true;
    repositories.claude-friction = {
      path = frictionRoot;
      # The alias from modules/home/ssh, so the push uses the deploy key rather
      # than the Yubikey. Darwin ignores this field; on Linux it is what
      # `git-sync-on-inotify` clones from when the directory is absent.
      uri = "git@claude-friction.github.com:entorenee/claude-friction.git";
      interval = 300;
    };
  };
}
