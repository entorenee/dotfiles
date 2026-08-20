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

  # Duplicated from settings.env deliberately, as artifactsRoot is: commits to
  # the friction repo are made by hand, so the path has to resolve in a plain
  # shell and not only inside a Claude session.
  home.sessionVariables.MY_CLAUDE_FRICTION_ROOT = frictionRoot;
}
