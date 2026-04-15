{
  lib,
  profile,
  ...
}:
lib.mkIf (profile == "work") {
  programs.claude-code = {
    settings = {
      permissions.allow = [
        "mcp__asana__get_me"
        "mcp__asana__get_task"
        "mcp__asana__get_tasks"
        "mcp__asana__get_my_tasks"
        "mcp__asana__get_project"
        "mcp__asana__get_projects"
        "mcp__asana__get_teams"
        "mcp__asana__get_user"
        "mcp__asana__get_users"
        "mcp__asana__get_attachments"
        "mcp__asana__search_tasks"
        "mcp__asana__search_objects"
        "mcp__asana__get_portfolio"
        "mcp__asana__get_portfolios"
        "mcp__asana__get_items_for_portfolio"
        "mcp__asana__get_status_overview"
      ];
      sandbox.filesystem = {
        allowRead = ["~/dotfiles" "~/code/work"];
        allowWrite = ["~/dotfiles" "~/code/work"];
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
