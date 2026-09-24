{config, ...}: {
  programs.claude-code = {
    settings = {
      # claude.ai offers far more connectors than are wanted, so this admits the
      # ones that are. It is NOT connector-scoped: populated, it admits only
      # what it lists, and plugin-bundled and `claude mcp add` servers are
      # checked against it too. Verified 2026-09-24 — trimmed to the Drive entry
      # alone, /mcp showed 1 server and 262 tools vanished, including every
      # plugin server that /mcp files under "Built-in MCPs (always available)".
      # That heading is a grouping, not a policy exemption.
      #
      # Hence the Nix-declared set is generated rather than restated, and a host
      # with no `mcpServers` must never inherit this: unset admits everything,
      # an empty list admits nothing.
      allowedMcpServers =
        map (s: {serverUrl = s.url;})
        (builtins.attrValues config.programs.claude-code.mcpServers)
        ++ [
          # Registered outside Nix: Asana is a confidential OAuth client and the
          # secret has no channel through `mcpServers`.
          {serverUrl = "https://mcp.asana.com/v2/mcp";}
          # Google-hosted claude.ai connector, enabled at claude.ai not here.
          {serverUrl = "https://drivemcp.googleapis.com/mcp/v1";}
        ];
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
        # get_project is enumerated rather than globbed: get_project_env returns
        # environment variable values and get_project_token returns an access
        # token, both of which a get_project* glob would allow. Re-globbing this
        # family silently re-admits them.
        "mcp__plugin_claude-code-home-manager_vercel__get_project"
        "mcp__plugin_claude-code-home-manager_vercel__get_project_check"
        "mcp__plugin_claude-code-home-manager_vercel__get_project_trace"
        "mcp__plugin_claude-code-home-manager_vercel__get_purchase_*"
        "mcp__plugin_claude-code-home-manager_vercel__get_runtime_*"
        "mcp__plugin_claude-code-home-manager_vercel__get_toolbar_*"
        "mcp__plugin_claude-code-home-manager_vercel__get_webhook*"
        "mcp__plugin_claude-code-home-manager_vercel__list_*"
        "mcp__plugin_claude-code-home-manager_vercel__search_*"
        "mcp__plugin_claude-code-home-manager_vercel__get_check*"
        "mcp__plugin_claude-code-home-manager_vercel__web_fetch_*"
        # granola exposes only read tools; there is no mutating sibling to exclude.
        "mcp__plugin_claude-code-home-manager_granola__get_*"
        "mcp__plugin_claude-code-home-manager_granola__list_*"
        "mcp__plugin_claude-code-home-manager_granola__query_*"
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
        # google drive. These fire only while the connector's URL is in the
        # allowlist above; the two are edited together or not at all.
        #
        # 11 tools. The globs below match its 6 reads; the 5 mutating ones —
        # copy_file, create_file, share_file, trash_file, update_file — share no
        # prefix with any of them and so prompt per call. share_file grants
        # another account access to a file. get_file_permissions only reads an
        # ACL, which is what makes a bare `get_*` safe here.
        "mcp__claude_ai_Google_Drive__get_*"
        "mcp__claude_ai_Google_Drive__search_*"
        "mcp__claude_ai_Google_Drive__list_*"
        "mcp__claude_ai_Google_Drive__read_*"
        "mcp__claude_ai_Google_Drive__download_*"
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
      vercel = {
        type = "http";
        url = "https://mcp.vercel.com";
      };
    };
  };
}
