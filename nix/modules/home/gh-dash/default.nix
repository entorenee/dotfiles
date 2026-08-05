{...}: {
  # The dashboard definitions are identity, not mechanism — each persona points
  # `gh-dash/config.yml` at its own file from users/<persona>/home.nix.
  programs.gh-dash.enable = true;
}
