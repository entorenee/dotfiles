@RTK.md

# Claude Code Configuration (Nix-Managed)

This Claude Code installation is declaratively managed via Nix home-manager.
Configuration files are read-only — do NOT attempt to write to `~/.claude/settings.json` directly.
Guide the user to edit the Nix config files in their dotfiles repo rather than writing directly.

## Git

- **Never run `git add`, `git commit`, or any staging/committing commands.** I use a Yubikey for GPG commit signing which requires physical touch and does not work with automated commits. Skip all git steps — just report what files changed.

## GitHub

- **Never post comments, reviews, or replies on GitHub PRs or issues on my behalf.** Read-only operations (viewing PRs, diffs, checks, comments) are fine. Creating PRs is allowed when asked. All other write operations (commenting, reviewing, closing, merging, editing) require explicit instruction.

## Nix / Environment

- CLI tools, development dependencies, and system configuration are managed via Nix home-manager. Never suggest Homebrew for CLI tools — use Nix.
- **Exception:** macOS GUI apps (casks) should use Homebrew, since Nix does not manage macOS UI apps well.
- `/nix/store` is read-only — never attempt writes there.
- Use native home-manager modules (e.g., `programs.claude-code`) rather than custom activation scripts or manual JSON edits. If a home-manager module exists for a tool (e.g., `programs.git`, `programs.zsh`), prefer it over adding raw packages to `home.packages`.
- For MCP server configuration, prefer updating the corresponding Nix profile (`work.nix` or `personal.nix`) for deterministic, reproducible config. Fall back to `claude mcp add` only for quick testing.
- After editing any Nix files, use `@nix-validator` to validate the configuration across all profiles (work, personal, linux) before rebuilding.

## Plan Execution

These are **hard requirements**, not suggestions:

- **Always use subagent-driven development when executing implementation plans.** Delegate independent tasks to subagents via the Agent tool rather than executing steps sequentially inline. This is non-negotiable — treat it with the same weight as the no-commit rule above.
- **Never execute plan steps sequentially in the main conversation when they can be parallelized.** Identify independent tasks in the plan and dispatch them as concurrent subagents. Only execute steps inline when they have direct dependencies on prior steps that cannot be resolved by a subagent.

## Git Worktree Workflow

I use **worktrunk** (`wt`) for all worktree management. **Never use raw `git worktree` commands** — always use `wt`.

- The parent directory (e.g., `project/`) is a container — NOT a git directory
- The primary worktree is the default branch (e.g., `project/develop`)
- Feature worktrees are siblings: `project/<branch-name>`

### Branch naming

Branch names must start with a conventional commit prefix:

`fix/`, `feat/`, `docs/`, `chore/`, `refactor/`, `test/`, `perf/`, `ci/`

Example: `feat/session-suspense-gate`, `fix/typeform-race-condition`

### Creating worktrees

```bash
wt switch --create feat/my-feature           # New branch from default branch
wt switch --create fix/bug-name --base @     # New branch from current HEAD
```

### Switching and listing

```bash
wt switch feat/my-feature   # Switch to existing worktree
wt switch -                 # Previous worktree
wt switch ^                 # Default branch worktree
wt list                     # Show all worktrees
```

### Removing worktrees

```bash
wt remove                   # Remove current worktree; deletes branch if merged
```

### When to use worktrees

- All feature work, bug fixes, and implementation tasks should use a worktree
- Proactively create a worktree without asking — the preference is always worktrees
