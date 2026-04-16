{ lib, profile, ... }:
lib.mkIf (profile == "personal") {
  programs.claude-code = {
    settings = {
      enabledPlugins = {
        "gopls-lsp@claude-plugins-official" = true;
      };
      sandbox.filesystem = {
        allowRead = ["~/dotfiles" "/nix/store"];
        allowWrite = ["~/dotfiles"];
      };
    };
  };
}
