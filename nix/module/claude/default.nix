{ config, lib, profile, ... }:
let
  configPath = "${config.home.homeDirectory}/dotfiles/nix/module/claude/config";
in {
  imports = [./work.nix ./personal.nix];

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
            {
              type = "command";
              command = "~/.claude/hooks/rtk-rewrite.sh";
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
        # Force Node's DNS resolution to prefer IPv4. The Claude Code sandbox
        # proxy binds to 127.0.0.1; Node 18+ defaults to IPv6-first lookups,
        # which fail before falling back. Tools like Vite/Vitest run lots of
        # short-lived Node processes that hit this constantly.
        NODE_OPTIONS = "--dns-result-order=ipv4first";
      };
      sandbox.enabled = true;
      sandbox.network.allowedDomains = [
        "registry.npmjs.org"
        "www.npmjs.com"
        "api.github.com"
        "github.com"
        "raw.githubusercontent.com"
        "objects.githubusercontent.com"
        "codeload.github.com"
        "asanausercontent.com"
      ];
      # Read-only registry-metadata queries run outside the sandbox so they
      # reuse the user's real ~/.npm and ~/.local/share/pnpm caches. The
      # sandbox still gates everything else (installs, builds, arbitrary
      # commands), and permissions / PreToolUse hooks still apply. These
      # commands cannot mutate the project — they only query the registry
      # and read package.json / lockfiles.
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
      ];
      statusLine = {
        type = "command";
        command = "~/.claude/statusline.sh";
      };
      hasSentTelemetryConsent = false;
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
        # Custom skills and slash commands authored in this repo
        # (nix/module/claude/config/{skills,commands}/) — both share the
        # Skill() permission gate since /<name> invokes the Skill tool.
        "Skill(asana-review)"
        "Skill(build-doctor)"
        "Skill(changelog-generation)"
        "Skill(code-hygiene)"
        "Skill(dependency-upgrades)"
        "Skill(investigate)"
        "Skill(npm-cve)"
        "Skill(pre-pr)"
        "Skill(pre-pr-autonomous)"
        # gh cli read-only
        "Bash(gh issue list*)"
        "Bash(gh issue view*)"
        "Bash(gh pr list*)"
        "Bash(gh pr view*)"
        "Bash(gh pr status*)"
        "Bash(gh pr checks*)"
        "Bash(gh pr diff*)"
        "Bash(gh pr create*)"
        "Bash(gh run list*)"
        "Bash(gh run view*)"
        "Bash(gh repo view*)"
        # gh api — broad allow; permissions.deny blocks all write verbs and -f/--field
        "Bash(gh api*)"
        # rtk wrapper (transparent proxy for token savings)
        "Bash(rtk *)"
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
        # pnpm exec — narrow to specific binaries; broader form previously allowed
        # `pnpm exec node`/`sh`/etc which is an arbitrary-code escape hatch
        "Bash(pnpm exec eslint*)"
        "Bash(pnpm exec jest*)"
        "Bash(pnpm exec tsc*)"
        "Bash(pnpm exec vitest*)"
        # pnpm monorepo filter (typecheck/lint:ci/test:ci against specific packages)
        "Bash(pnpm --filter*)"
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
        # WebFetch — general-purpose research surface for dependency upgrades
        # and migration guides. Mirrors the sandbox.network.allowedDomains list.
        "WebFetch(domain:github.com)"
        "WebFetch(domain:raw.githubusercontent.com)"
        "WebFetch(domain:www.npmjs.com)"
        "WebFetch(domain:registry.npmjs.org)"
      ];
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
        # Block posting comments/reviews on GitHub on my behalf
        "Bash(gh pr comment*)"
        "Bash(gh pr review*)"
        "Bash(gh pr close*)"
        "Bash(gh pr merge*)"
        "Bash(gh pr edit*)"
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
        "Read(~/.pypirc)"
        "Read(~/.gem/credentials)"
        "Read(~/Library/Keychains/**)"
      ];
    };
  };

  programs.zsh.shellAliases = {
    claude-yolo = "claude --dangerously-skip-permissions";
  };

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/CLAUDE.md";
  home.file.".claude/RTK.md".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/RTK.md";

  home.file.".claude/hooks".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/hooks";

  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/skills";

  home.file.".claude/agents".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/agents";

  home.file.".claude/commands".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/commands";

  home.file.".claude/statusline.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/statusline.sh";
}
