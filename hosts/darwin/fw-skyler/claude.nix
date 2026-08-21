{...}: {
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
        # NOTE: posthog exposes only a generic `exec` tool — intentionally NOT
        # allowlisted (arbitrary query/command surface; should prompt each time)
        # google drive read-only (get_/search_/list_/read_/download_ prefixes)
        "mcp__googledrive__get_*"
        "mcp__googledrive__search_*"
        "mcp__googledrive__list_*"
        "mcp__googledrive__read_*"
        "mcp__googledrive__download_*"
        # create_file is the one mutating tool deliberately allowed — it lets
        # the investigation skills export reports as native Google Docs.
        # copy_file (the other write verb) is left to prompt each time.
        "mcp__googledrive__create_file"
        # Docs for the MCP servers declared below. Explicit hosts, never
        # "*.example.com" — same rule as webFetchHosts in the base module.
        "WebFetch(domain:docs.sentry.io)"
        "WebFetch(domain:posthog.com)"
        "WebFetch(domain:mcp.posthog.com)"
      ];
      sandbox.filesystem = {
        allowRead = ["~/dotfiles" "~/code/work" "~/.config/gh" "/nix/store" "/tmp" "/private/tmp"];
        allowWrite = ["~/dotfiles" "~/code/work" "/tmp" "/private/tmp"];
      };
    };

    mcpServers = {
      expo = {
        type = "http";
        url = "https://mcp.expo.dev/mcp";
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
