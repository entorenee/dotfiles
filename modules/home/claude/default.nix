{
  config,
  lib,
  ...
}: let
  configPath = "${config.home.homeDirectory}/dotfiles/modules/home/claude/config";

  # Repo-authored skills and slash commands; /<name> invokes the Skill tool for
  # both. Read from the same directories home.file uses, so this cannot drift.
  skillNames =
    builtins.attrNames (builtins.readDir ./config/skills)
    ++ map (lib.removeSuffix ".md")
    (builtins.attrNames
      (lib.filterAttrs (_: type: type == "regular") (builtins.readDir ./config/commands)));

  # Explicit hosts, never "*.example.com" — a subdomain wildcard trusts every
  # host anyone can stand up there (*.github.io = any GitHub user's page).
  # A WebFetch rule also pre-allows its host for the Bash sandbox, not the
  # reverse, so these are deliberately absent from allowedDomains below.
  webFetchHosts = [
    "github.com"
    "raw.githubusercontent.com"
    "www.npmjs.com"
    "registry.npmjs.org"
    "getstream.io" # Stream Chat docs, at /chat/docs
    "nikitabobko.github.io" # AeroSpace docs, at /AeroSpace/guide
  ];
in {
  programs.claude-code = {
    enable = true;
    settings = {
      hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "~/.claude/hooks/pnpm-guard.sh";
            }
            # Runs before rtk-rewrite so it inspects the command as written,
            # not the rewritten `rtk ...` form.
            {
              type = "command";
              command = "~/.claude/hooks/exec-form-guard.sh";
            }
            {
              type = "command";
              command = "~/.claude/hooks/rtk-rewrite.sh";
            }
          ];
        }
      ];
      hooks.Notification = [
        {
          matcher = "permission_prompt|idle_prompt";
          hooks = [
            {
              type = "command";
              command = "~/.claude/hooks/notify-attention.sh";
            }
          ];
        }
      ];
      enabledPlugins = {
        "typescript-lsp@claude-plugins-official" = true;
        "superpowers@superpowers-marketplace" = true;
        "frontend-design@claude-plugins-official" = true;
        "lua-lsp@claude-plugins-official" = true;
        "pr-review-toolkit@claude-plugins-official" = true;
      };
      env = {
        ENABLE_CLAUDEAI_MCP_SERVERS = "false";
        DISABLE_AUTOUPDATER = "1";
        # The sandbox proxy binds 127.0.0.1 only; Node 18+ tries IPv6 first and
        # fails before falling back. Costly with short-lived Vite/Vitest procs.
        NODE_OPTIONS = "--dns-result-order=ipv4first";
      };
      sandbox.enabled = true;
      # Only hosts Bash reaches that WebFetch never does. Everything in
      # webFetchHosts is already pre-allowed here by its WebFetch rule.
      sandbox.network.allowedDomains = [
        "api.github.com"
        "codeload.github.com"
        "objects.githubusercontent.com"
        "asanausercontent.com"
      ];
      # Identity roles allow the whole gh config dir; this re-blocks the one
      # file an OAuth token could land in. denyRead wins over allowRead.
      sandbox.filesystem.denyRead = ["~/.config/gh/hosts.yml"];

      # Registry-metadata reads run unsandboxed so they reuse the real ~/.npm
      # and pnpm caches. They cannot mutate the project, and permissions plus
      # PreToolUse hooks still apply.
      sandbox.excludedCommands = [
        "npm outdated*"
        "npm view *"
        "npm explain*"
        "npm audit*"
        "npx npm-check-updates*"
        "npx --yes npm-check-updates*"
        "npx ncu*"
        "npx --yes ncu*"
        "pnpm outdated*"
        "pnpm view *"
        "pnpm why *"
        "pnpm audit*"
        "pnpm dlx npm-check-updates*"
        "pnpm dlx ncu*"
        "pnpm exec ncu*"
        # Same IPv6-first problem as NODE_OPTIONS above, but Go has no knob: gh
        # dials the proxy at [::1] and every call fails with `proxyconnect`.
        # Docs prescribe excludedCommands for Go CLIs. Safe because this governs
        # only sandbox network/fs — permissions.deny still blocks gh writes.
        "gh *"
        # The rtk-rewrite hook turns `gh ...` into `rtk gh ...` before the
        # sandbox decision, so `gh *` alone never matches and gh ends up
        # sandboxed — where denyRead on hosts.yml stops it from even starting
        # ("failed to create root command"). Both forms have to be listed.
        "rtk gh *"
        # Nix needs the daemon socket, which the sandbox blocks. Read-only
        # evaluation only: builds, rebuilds, and `nix run`/`develop`/`shell`/
        # `repl` are omitted so they stay sandboxed. rtk rewrites none of these.
        "nix eval *"
        "nix flake show*"
        "nix flake metadata*"
        "nix search*"
      ];
      statusLine = {
        type = "command";
        command = "~/.claude/statusline.sh";
      };
      hasSentTelemetryConsent = false;
      model = "opus";
      tui = "fullscreen";
      preferences = {
        alwaysThinkingEnabled = true;
        cleanupPeriodDays = 365;
      };
      permissions.allow = [
        # Read access for dotfiles (skills, agents, nix modules)
        "Read(~/dotfiles/**)"
        "Read(/nix/store/**)"
        # Trusted skill namespaces (plugins explicitly enabled above)
        "Skill(superpowers:*)"
        "Skill(pr-review-toolkit:*)"
        "Skill(frontend-design:*)"
        # Custom skills and slash commands are appended below from skillNames.
        # gh cli read-only
        "Bash(gh issue list*)"
        "Bash(gh issue view*)"
        "Bash(gh pr list*)"
        "Bash(gh pr view*)"
        "Bash(gh pr status*)"
        "Bash(gh pr checks*)"
        "Bash(gh pr diff*)"
        # Draft only; a non-draft `gh pr create` falls through to a prompt.
        "Bash(gh pr create *--draft*)"
        "Bash(gh run list*)"
        "Bash(gh run view*)"
        "Bash(gh repo view*)"
        "Bash(gh release list*)"
        # gh api — broad allow; permissions.deny blocks all write verbs and -f/--field
        "Bash(gh api*)"
        # rtk wrapper (transparent proxy for token savings)
        "Bash(rtk *)"
        # worktrunk (see CLAUDE.md). `wt remove` is omitted — it deletes the
        # branch when merged, so it should prompt.
        "Bash(wt switch*)"
        "Bash(wt list*)"
        # git read-only
        "Bash(git log*)"
        "Bash(git diff*)"
        "Bash(git show*)"
        "Bash(git branch*)"
        "Bash(git blame*)"
        "Bash(git stash list*)"
        "Bash(git worktree list*)"
        "Bash(git remote*)"
        "Bash(git rev-parse*)"
        "Bash(git merge-base*)"
        "Bash(git tag*)"
        "Bash(git describe*)"
        "Bash(git ls-files*)"
        "Bash(git --no-pager *)"
        # npm read-only
        "Bash(npm ls*)"
        "Bash(npm outdated*)"
        "Bash(npm explain*)"
        "Bash(npm view*)"
        "Bash(npm pkg get*)"
        "Bash(npm audit*)"
        "Bash(npm run --list*)"
        # npm-check-updates (read-only when --jsonUpgraded; mutates only with -u/--upgrade)
        "Bash(npx --yes npm-check-updates*)"
        "Bash(npx npm-check-updates*)"
        "Bash(npx --yes ncu*)"
        "Bash(npx ncu*)"
        "Bash(pnpm dlx npm-check-updates*)"
        "Bash(pnpm dlx ncu*)"
        "Bash(pnpm exec ncu*)"
        # npm build/test
        "Bash(npm test*)"
        "Bash(npm run test*)"
        "Bash(npm run lint*)"
        "Bash(npm run tsc*)"
        "Bash(npm run build*)"
        "Bash(npm run dev*)"
        "Bash(npm ci*)"
        "Bash(npm install*)"
        "Bash(pnpm --version*)"
        # pnpm read-only
        "Bash(pnpm ls*)"
        "Bash(pnpm list*)"
        "Bash(pnpm outdated*)"
        "Bash(pnpm view*)"
        "Bash(pnpm why *)"
        "Bash(pnpm audit*)"
        # pnpm build/test (both `pnpm <script>` and `pnpm run <script>` forms)
        "Bash(pnpm test*)"
        "Bash(pnpm jest*)"
        "Bash(pnpm typecheck*)"
        "Bash(pnpm lint*)"
        "Bash(pnpm build*)"
        "Bash(pnpm run test*)"
        "Bash(pnpm run lint*)"
        "Bash(pnpm run tsc*)"
        "Bash(pnpm run typecheck*)"
        "Bash(pnpm run build*)"
        "Bash(pnpm run dev*)"
        "Bash(pnpm install*)"
        "Bash(pnpm add*)"
        # pnpm exec — named binaries only; the bare form is a code-exec hatch.
        "Bash(pnpm exec eslint*)"
        "Bash(pnpm exec jest*)"
        "Bash(pnpm exec tsc*)"
        "Bash(pnpm exec vitest*)"
        # Monorepo filter; both orderings occur: `pnpm --filter <pkg> run <s>`
        # and `pnpm run --filter <pkg> exec <bin>`.
        "Bash(pnpm --filter*)"
        "Bash(pnpm run --filter*)"
        # turbo
        "Bash(pnpm turbo *)"
        "Bash(npx turbo *)"
        # typescript direct
        "Bash(npx tsc*)"
        "Bash(tsc *)"
        # test runner
        "Bash(npx vitest *)"
        # linter (read-only by default; --fix mutates)
        "Bash(npx eslint *)"
        # expo
        "Bash(npx expo *)"
        # nix read-only
        "Bash(nix eval *)"
        "Bash(nix flake show*)"
        "Bash(nix flake metadata*)"
        "Bash(darwin-rebuild switch*--dry-run*)"
        # aerospace read-only verbs. rtk has no equivalent (exit 1), so these
        # are not already covered by Bash(rtk *). Excludes focus /
        # move-node-to-workspace / reload-config, which mutate window state.
        "Bash(aerospace list-*)"
        "Bash(aerospace config --get*)"
      ]
      ++ map (name: "Skill(${name})") skillNames
      ++ map (host: "WebFetch(domain:${host})") webFetchHosts;
      permissions.deny = [
        "Bash(rm -rf *)"
        "Bash(rm -fr *)"
        "Bash(rm -r *)"
        "Bash(rm -f *)"
        "Bash(sudo *)"
        "Bash(mkfs *)"
        "Bash(dd *)"
        "Bash(wget *|bash*)"
        "Bash(wget *| bash*)"
        "Bash(curl *|bash*)"
        "Bash(curl *| bash*)"
        "Bash(curl *|sh*)"
        "Bash(curl *| sh*)"
        "Bash(chmod 777 *)"
        "Bash(git push --force*)"
        "Bash(git push *--force*)"
        "Bash(git push --force-with-lease*)"
        "Bash(git push *--force-with-lease*)"
        "Bash(git reset --hard*)"
        "Bash(git commit*)"
        # rtk proxy is an arbitrary-command escape hatch (per RTK.md)
        "Bash(rtk proxy*)"
        # pnpm exec sandbox escapes — block interpreters / shells / rm via pnpm exec
        "Bash(pnpm exec node*)"
        "Bash(pnpm exec sh*)"
        "Bash(pnpm exec bash*)"
        "Bash(pnpm exec rm*)"
        # accidental package publish guards
        "Bash(npm publish*)"
        "Bash(pnpm publish*)"
        # Block posting comments/reviews on GitHub on my behalf.
        # `gh pr edit` is NOT here — it edits my own PR's title/body, which is
        # part of the normal create-draft → write-body flow. It lives in
        # permissions.ask so it confirms per-use ("editing requires explicit
        # instruction") instead of being hard-blocked.
        "Bash(gh pr comment*)"
        "Bash(gh pr review*)"
        "Bash(gh pr close*)"
        "Bash(gh pr merge*)"
        "Bash(gh issue comment*)"
        "Bash(gh issue create*)"
        "Bash(gh issue close*)"
        "Bash(gh issue edit*)"
        "Bash(gh api *-f *)"
        "Bash(gh api *--field *)"
        "Bash(gh api *-X POST*)"
        "Bash(gh api *-X PATCH*)"
        "Bash(gh api *-X PUT*)"
        "Bash(gh api *-X DELETE*)"
        "Bash(gh api *--method POST*)"
        "Bash(gh api *--method PATCH*)"
        "Bash(gh api *--method PUT*)"
        "Bash(gh api *--method DELETE*)"
        "Edit(~/.bashrc)"
        "Edit(~/.zshrc)"
        "Edit(~/.ssh/**)"
        "Read(~/.ssh/**)"
        "Read(~/.gnupg/**)"
        "Read(~/.aws/**)"
        "Read(~/.azure/**)"
        "Read(~/.config/gh/**)"
        "Read(~/.git-credentials)"
        "Read(~/.docker/config.json)"
        "Read(~/.kube/**)"
        "Read(~/.npmrc)"
        "Read(~/.npm/**)"
        # Project-level .npmrc may contain private registry tokens (_authToken).
        # Block all reads to prevent secret exfiltration via the Read tool or
        # common shell utilities.
        "Read(**/.npmrc)"
        "Bash(cat *.npmrc*)"
        "Bash(grep *.npmrc*)"
        "Bash(head *.npmrc*)"
        "Bash(tail *.npmrc*)"
        # Whole env family, .env.example included — usually a placeholder, not
        # guaranteed to be. `**/` is project-relative, so this guards the project
        # Claude is working in, not the filesystem. Read tool only: rtk rewrites
        # `cat .env` into the allowed `rtk read`, so Bash patterns can't work.
        "Read(**/.env)"
        "Read(**/.env.*)"
        "Read(~/.pypirc)"
        "Read(~/.gem/credentials)"
        "Read(~/Library/Keychains/**)"
      ];
      permissions.ask = [
        # Editing my own PR's title/body is allowed "with explicit instruction"
        # (per global CLAUDE.md) — so confirm per-use rather than deny outright.
        # Catches reviewer/assignee edits too, which is the desired gate.
        "Bash(gh pr edit*)"
      ];
    };
  };

  programs.zsh.shellAliases = {
    claude-yolo = "claude --dangerously-skip-permissions";
  };

  # Every managed entry is the same mapping: ~/.claude/<path> maps to
  # config/<path> (out-of-store symlink when config.my.dotfiles.mutable, a
  # store copy otherwise — see modules/options.nix). Listing the relative
  # paths once keeps the ".claude/" prefix and that choice in a single place.
  #
  # Skills are enumerated individually rather than symlinking the whole skills/
  # directory. home-manager ≥ 2026-07 installs the generated MCP plugin as a
  # personal plugin at ~/.claude/skills/claude-code-home-manager (for Claude Code
  # ≥ 2.1.157). A single out-of-store symlink for the entire skills/ dir collides
  # with that nested entry ("Error installing file ... outside $HOME"). Per-skill
  # symlinks let ~/.claude/skills be a real directory the module can also write
  # into. Skill names are read from the flake source at eval time, so adding a
  # new skill directory requires a rebuild.
  home.file = builtins.listToAttrs (
    map
    (path: {
      name = ".claude/${path}";
      value.source =
        if config.my.dotfiles.mutable
        then config.lib.file.mkOutOfStoreSymlink "${configPath}/${path}"
        else ./config/${path};
    })
    (
      [
        "CLAUDE.md"
        "RTK.md"
        "hooks"
        "agents"
        "commands"
        "statusline.sh"
      ]
      ++ map (name: "skills/${name}")
      (builtins.attrNames (builtins.readDir ./config/skills))
    )
  );
}
