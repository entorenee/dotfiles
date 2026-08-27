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
        # vercel read-only (list_/search_/check_/web_fetch_ prefixes;
        # add_/change_/deploy_/edit_/reply_ are mutating and not matched)
        #
        # `get_*` is deliberately NOT a single glob. get_access_to_vercel_url
        # reads like a getter but returns a bypass for a protected deployment,
        # so it is left off the allowlist to be considered per call — same
        # treatment as copy_file and posthog's exec below. The families below
        # are globs rather than 12 exact names so a new get_deployment_* or
        # get_runtime_* tool is covered without another edit.
        "mcp__plugin_claude-code-home-manager_vercel__get_agent_run*"
        "mcp__plugin_claude-code-home-manager_vercel__get_deployment*"
        "mcp__plugin_claude-code-home-manager_vercel__get_domain_*"
        "mcp__plugin_claude-code-home-manager_vercel__get_project*"
        "mcp__plugin_claude-code-home-manager_vercel__get_purchase_*"
        "mcp__plugin_claude-code-home-manager_vercel__get_runtime_*"
        "mcp__plugin_claude-code-home-manager_vercel__get_toolbar_*"
        "mcp__plugin_claude-code-home-manager_vercel__get_web_*"
        "mcp__plugin_claude-code-home-manager_vercel__list_*"
        "mcp__plugin_claude-code-home-manager_vercel__search_*"
        "mcp__plugin_claude-code-home-manager_vercel__check_*"
        "mcp__plugin_claude-code-home-manager_vercel__web_fetch_*"
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
        "mcp__plugin_claude-code-home-manager_expo__*_crashes"
        # Named in full rather than globbed: `*_reviews` would sit one character
        # from `appstore_reply_review` and `playstore_reply_review`, which post
        # public replies. The suffix globs above are safe because nothing
        # mutating ends in _info/_list/_logs/_crashes.
        "mcp__plugin_claude-code-home-manager_expo__appstore_reviews"
        "mcp__plugin_claude-code-home-manager_expo__playstore_reviews"
        # Reads documentation and returns an `expo install` command as text; it
        # installs nothing.
        "mcp__plugin_claude-code-home-manager_expo__add_library"
        # NOTE: posthog exposes only a generic `exec` tool — intentionally NOT
        # allowlisted (arbitrary query/command surface; should prompt each time)
        # Docs for the MCP servers declared below. Explicit hosts, never
        # "*.example.com" — same rule as webFetchHosts in the base module.
        "WebFetch(domain:docs.sentry.io)"
        "WebFetch(domain:posthog.com)"
        "WebFetch(domain:mcp.posthog.com)"
        "WebFetch(domain:docs.slack.dev)"
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
      granola = {
        type = "http";
        url = "https://mcp.granola.ai/mcp";
      };
      sentry = {
        type = "http";
        url = "https://mcp.sentry.dev/mcp";
      };
      posthog = {
        type = "http";
        url = "https://mcp.posthog.com/mcp";
      };
      # Slack rejects dynamic client registration, so this entry names an OAuth
      # client where the others don't. Both values are public and identical for
      # every user — they identify Slack's own app, not this workspace, and are
      # committed to slackapi/slack-mcp-plugin. PKCE public client: there is no
      # secret, so nothing is missing here.
      slack = {
        type = "http";
        url = "https://mcp.slack.com/mcp";
        oauth = {
          clientId = "1601185624273.8899143856786";
          callbackPort = 3118;
        };
      };
      vercel = {
        type = "http";
        url = "https://mcp.vercel.com";
      };
    };
  };
}
