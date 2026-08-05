{
  lib,
  navi-cheatsheets,
  private-assets,
  tmux-powerkit,
  worktrunk,
}: system: username: {
  inherit lib username private-assets tmux-powerkit worktrunk;
  navi-cheatsheets = navi-cheatsheets.packages.${system}.default;
}
