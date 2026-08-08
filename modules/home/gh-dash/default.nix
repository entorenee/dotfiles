{...}: {
  # The dashboard definitions are identity, not mechanism — each identity role
  # points `gh-dash/config.yml` at its own file (roles/home/personal.nix, or
  # hosts/darwin/fw-skyler/home.nix).
  programs.gh-dash.enable = true;
}
