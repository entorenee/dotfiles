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
- **Do not auto-run `@nix-validator` after every Nix edit.** For simple, low-risk changes, ask before running it. For large refactors, use your judgment to validate at critical checkpoints.

## Project Command Discovery

These are **hard requirements**, not suggestions:

Before running any build, test, lint, typecheck, format, or package-manager command in a project, you MUST first discover the project's actual conventions. Do not guess from defaults (`npm test`, `npm run lint`, etc.) — guessing wastes attempts and pollutes diffs.

**Required discovery steps, in order:**

1. **Read `package.json`** at the repo root. Look at the `scripts` block and use the exact key names defined there:
   - typecheck: commonly `typecheck`, `tsc`, `type-check` — sometimes only via the monorepo orchestrator
   - lint: prefer a non-mutating variant if one exists (`lint:ci`, `lint:check`) over `lint` or `lint:fix`
   - test: prefer `test:ci` over `test` when both exist (CI variants are usually deterministic and non-interactive)
   - build: prefer `build:ci` over `build` when both exist
2. **Detect the package manager** from the lockfile present at the repo root: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lockb` → bun, `package-lock.json` → npm. Use that package manager consistently — never default to `npm` if another lockfile is present.
3. **Detect monorepo orchestrators**: `turbo.json` → use `<pm> turbo <task>` and prefer `--filter='...[<merge-base>]'` to scope to affected packages. `nx.json` → use `nx affected`. `lerna.json`, `pnpm-workspace.yaml` → respect workspace boundaries.
4. **Read the nearest `CLAUDE.md`** — repo root first, then any that sits closer to the files you're editing. Capture documented conventions: logging helpers (e.g. `logError` vs `console.error` vs `logger.error`), error wrappers, banned APIs, import alias rules, test file patterns. These override generic defaults.
5. **Non-JS projects:** read the equivalent manifest — `Cargo.toml`, `pyproject.toml` / `uv.lock`, `go.mod`, `Gemfile`, `mix.exs`, plus any `Makefile` / `justfile` — and use those canonical commands instead of inventing your own.

**When delegating to subagents:** pass the discovered commands and conventions verbatim in the prompt. Subagents do not inherit your discovery work — if you tell them to "run the tests," they will guess. Tell them "run `pnpm test:ci`" with the full PROJECT_COMMANDS block.

**When you don't have access to `package.json`** (e.g. running in a directory above the project root): say so explicitly and ask before running any command. Do not fall back to defaults.

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

### Memory across worktrees

Claude's per-project memory directory (`~/.claude/projects/<encoded-cwd>/memory/`) is keyed by the working directory, so each worktree gets its own isolated memory. Memories saved in a feature worktree's directory disappear when that worktree is removed and are invisible from sibling worktrees.

**Rule:** When saving project- or repo-wide memory (e.g., `project` or `feedback` types that apply beyond the current task), write it to the **default-branch worktree's** memory directory, not the current feature worktree's. For AdminPortal that's `~/.claude/projects/-Users-fw-skylerlemay-code-work-AdminPortal-develop/memory/`. Use the current worktree's memory only for memories scoped to the in-progress branch work that won't be relevant after the branch merges.
