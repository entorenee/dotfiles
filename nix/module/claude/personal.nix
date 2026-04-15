{ lib, profile, ... }:
lib.mkIf (profile == "personal") {
  programs.claude-code = {
    settings = {
      sandbox.filesystem = {
        allowRead = ["~/dotfiles"];
        allowWrite = ["~/dotfiles"];
      };
    };
  };
}
