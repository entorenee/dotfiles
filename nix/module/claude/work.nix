{
  lib,
  profile,
  ...
}:
lib.mkIf (profile == "work") {
  programs.claude-code = {
    settings = {
      sandbox.permissions = {
        read.allow = ["~/dotfiles" "~/code/work"];
        write.allow = ["~/dotfiles" "~/code/work"];
      };
    };

    mcpServers = {
      betterstack = {
        type = "http";
        url = "https://mcp.betterstack.com";
      };
      sentry = {
        type = "http";
        url = "https://mcp.sentry.dev/mcp";
      };
      posthog = {
        type = "http";
        url = "https://mcp.posthog.com/mcp";
      };
    };
  };
}
