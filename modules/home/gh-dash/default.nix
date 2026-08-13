{...}: {
  # No dashboard definitions here: they are identity, not mechanism, so each
  # identity role points `gh-dash/config.yml` at its own file.
  programs.gh-dash.enable = true;
}
