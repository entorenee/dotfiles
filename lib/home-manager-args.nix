{
  lib,
  navi-cheatsheets,
  tmux-powerkit,
  worktrunk,
}: system: username: {
  inherit lib username tmux-powerkit worktrunk;
  navi-cheatsheets = navi-cheatsheets.packages.${system}.default;
}
