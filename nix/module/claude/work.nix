{
  lib,
  profile,
  ...
}:
lib.mkIf (profile == "work") {
  programs.claude-code = {
    settings = {
      permissions.allow = [
        # Read access for cross-project paths (worktrees, sibling packages)
        "Read(~/code/work/**)"
        # asana read-only
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
        # vercel read-only
        "mcp__plugin_claude-code-home-manager_vercel__get_deployment"
        "mcp__plugin_claude-code-home-manager_vercel__get_deployment_build_logs"
        "mcp__plugin_claude-code-home-manager_vercel__get_runtime_logs"
        "mcp__plugin_claude-code-home-manager_vercel__get_project"
        "mcp__plugin_claude-code-home-manager_vercel__list_projects"
        "mcp__plugin_claude-code-home-manager_vercel__list_deployments"
        "mcp__plugin_claude-code-home-manager_vercel__list_teams"
        "mcp__plugin_claude-code-home-manager_vercel__list_toolbar_threads"
        "mcp__plugin_claude-code-home-manager_vercel__get_toolbar_thread"
        "mcp__plugin_claude-code-home-manager_vercel__check_domain_availability_and_price"
        "mcp__plugin_claude-code-home-manager_vercel__search_vercel_documentation"
        "mcp__plugin_claude-code-home-manager_vercel__get_access_to_vercel_url"
        "mcp__plugin_claude-code-home-manager_vercel__web_fetch_vercel_url"
      ];
      sandbox.filesystem = {
        allowRead = ["~/dotfiles" "~/code/work" "/nix/store" "/tmp" "/private/tmp"];
        allowWrite = ["~/dotfiles" "~/code/work" "/tmp" "/private/tmp"];
      };
    };

    mcpServers = {
      expo = {
        type = "http";
        url = "https://mcp.expo.dev/mcp";
      };
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
      vercel = {
        type = "http";
        url = "https://mcp.vercel.com";
      };
    };
  };
}
