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
        # asana read-only (get_/search_ prefixes; mutating tools use add_/create_/
        # delete_/save_/update_/log_ and are not matched)
        "mcp__asana__get_*"
        "mcp__asana__search_*"
        # vercel read-only (get_/list_/search_/check_/web_fetch_ prefixes;
        # add_/change_/deploy_/edit_/reply_ are mutating and not matched)
        "mcp__plugin_claude-code-home-manager_vercel__get_*"
        "mcp__plugin_claude-code-home-manager_vercel__list_*"
        "mcp__plugin_claude-code-home-manager_vercel__search_*"
        "mcp__plugin_claude-code-home-manager_vercel__check_*"
        "mcp__plugin_claude-code-home-manager_vercel__web_fetch_*"
        # sentry read-only (whoami + find_/get_/search_ prefixes)
        # Excludes analyze_issue_with_seer (billed AI call)
        "mcp__plugin_claude-code-home-manager_sentry__whoami"
        "mcp__plugin_claude-code-home-manager_sentry__find_*"
        "mcp__plugin_claude-code-home-manager_sentry__get_*"
        "mcp__plugin_claude-code-home-manager_sentry__search_*"
        # expo read-only (docs, testflight, *_info/*_list/*_logs/workflow_validate)
        # Mutating siblings build_cancel/run/submit and workflow_cancel/create/run
        # are NOT matched because they don't end in _info/_list/_logs/_validate
        "mcp__plugin_claude-code-home-manager_expo__learn"
        "mcp__plugin_claude-code-home-manager_expo__read_*"
        "mcp__plugin_claude-code-home-manager_expo__search_*"
        "mcp__plugin_claude-code-home-manager_expo__testflight_*"
        "mcp__plugin_claude-code-home-manager_expo__*_info"
        "mcp__plugin_claude-code-home-manager_expo__*_list"
        "mcp__plugin_claude-code-home-manager_expo__*_logs"
        "mcp__plugin_claude-code-home-manager_expo__workflow_validate"
        # betterstack read-only — telemetry + uptime
        # Globs cover list_/get_/build_ (telemetry_build_*query*_tool, both read);
        # mutating verbs (add/create/delete/edit/import/move/remove/rename/toggle/
        # update/acknowledge/escalate/resolve/reopen) are not matched.
        "mcp__plugin_claude-code-home-manager_betterstack__better_stack_search_*"
        "mcp__plugin_claude-code-home-manager_betterstack__telemetry_query"
        "mcp__plugin_claude-code-home-manager_betterstack__telemetry_chart"
        "mcp__plugin_claude-code-home-manager_betterstack__telemetry_export_dashboard_tool"
        "mcp__plugin_claude-code-home-manager_betterstack__telemetry_list_*"
        "mcp__plugin_claude-code-home-manager_betterstack__telemetry_get_*"
        "mcp__plugin_claude-code-home-manager_betterstack__telemetry_build_*"
        "mcp__plugin_claude-code-home-manager_betterstack__uptime_list_*"
        "mcp__plugin_claude-code-home-manager_betterstack__uptime_get_*"
        # NOTE: posthog exposes only a generic `exec` tool — intentionally NOT
        # allowlisted (arbitrary query/command surface; should prompt each time)
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
