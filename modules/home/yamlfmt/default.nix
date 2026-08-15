{pkgs, ...}: {
  # Deployed as yamlfmt/.yamlfmt, not .yamlfmt: yamlfmt's own lookup is
  # $XDG_CONFIG_HOME/yamlfmt/.yamlfmt, so this location is found without a
  # -conf flag. conform.nvim's built-in formatter then works unmodified.
  xdg.configFile."yamlfmt/.yamlfmt".source = ./config/.yamlfmt;

  # Keep the binary with the config it configures — without it the file above is
  # inert wherever Mason has not fetched yamlfmt.
  home.packages = [pkgs.yamlfmt];
}
