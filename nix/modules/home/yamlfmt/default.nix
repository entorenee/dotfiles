{...}: {
  # Deployed as yamlfmt/.yamlfmt, not .yamlfmt: yamlfmt's own lookup is
  # $XDG_CONFIG_HOME/yamlfmt/.yamlfmt, so this location is found without a
  # -conf flag. conform.nvim's built-in formatter then works unmodified.
  xdg.configFile."yamlfmt/.yamlfmt".source = ./config/.yamlfmt;
}
