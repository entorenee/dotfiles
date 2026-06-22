@RTK.md

# Claude Code Configuration (Nix-Managed)

This Claude Code installation is declaratively managed via Nix home-manager.
Configuration files are read-only — do NOT attempt to write to `~/.claude/settings.json` directly.
Guide the user to edit the Nix config files in their dotfiles repo rather than writing directly.

## Git

- **Never run `git add`, `git commit`, or any staging/committing commands.** I use a Yubikey for GPG commit signing which requires physical touch and does not work with automated commits. Skip all git steps — just report what files changed.

## Bash

- **Never use a bare `~` in a variable assignment value** (e.g. `F=~/path`). Bash expands the tilde at assignment time, which trips a safety warning on every such command. Use `F="$HOME/path"` or an absolute path instead — identical behavior, no prompt.

## GitHub

- **Never post comments, reviews, or replies on GitHub PRs or issues on my behalf.** Read-only operations (viewing PRs, diffs, checks, comments) are fine. Creating PRs is allowed when asked. All other write operations (commenting, reviewing, closing, merging, editing) require explicit instruction.

## Inclusive Language

- **Never infer or assign gender to anyone whose gender has not been explicitly stated.** Do not guess from a name, GitHub username, email, photo, or any other indirect signal. Assuming gender from names perpetuates bias in the tech industry.
- Use `they`/`them`/`their` or the person's name/handle directly. Applies to PR reviewers, commit authors, teammates, ticket commenters, customers in logs, and any other third party in PR summaries, code-history narration, ticket triage, status updates, postmortems, etc.
- If you catch yourself having used `he`/`she` for someone whose gender wasn't stated, silently restate the relevant passage with neutral language and move on — no apology theater.

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

## Scope & Approach

These are **hard requirements**, not suggestions:

- **For any non-trivial change, state scope before editing.** Before touching code on a task that isn't a one-line or mechanical edit, post: (1) a one-sentence scope statement, (2) a 3-bullet approach, and (3) what is explicitly **out of scope**. Then pause for confirmation. This applies to ad-hoc tasks too — not just work routed through the `feature-design-doc` / `feature-plan` skills.
- **Spend at most a couple of tool calls locating relevant code before proposing the plan.** For pure lookups ("where is X?"), return the answer only — do not begin changes. Do not investigate at length before acting; surface a short plan first, then execute.
- **Remove obsolete logic rather than layering new code beside it.** When a change supersedes existing logic (e.g. replacing a text-based check with a status-code check), delete the old path in the same change unless told to keep it. Do not leave both alive.
- **Do not expand scope or bundle out-of-scope work into a commit without explicit approval.** If you discover adjacent work worth doing, name it and ask — do not fold it in.
- **Route bug, test-failure, and unexpected-behavior investigations through the `investigate` skill.** It enforces the scope control and root-cause verification above. Invoke it before proposing a fix rather than debugging ad-hoc.

## Code Review & Diagnosis

These are **hard requirements**, not suggestions:

- **Do not label a finding "Critical" (or assert a root cause) without evidence from the actual code.** Quote the exact diff line or error message that supports the claim, and rate severity only on what is literally present in the changed code — never on an agent's summary, a theory, or an assumption.
- **When relaying subagent review findings, verify each against the real diff before presenting it.** Agent summaries overstate; downgrade or drop any finding you cannot ground in the actual change.

## Verification

These are **hard requirements**, not suggestions:

- **After code changes, run typecheck, lint, and tests, and report pass/fail per check before claiming the task is complete.** Use the commands discovered via Project Command Discovery above — do not guess them.
- **If a worktree is missing the binaries to verify** (broken symlink, uninstalled deps, etc.), say so explicitly and report what could not be run. Never silently skip verification and imply it passed.

## Plan Execution

These are **hard requirements**, not suggestions:

- **Always use subagent-driven development when executing implementation plans.** Delegate independent tasks to subagents via the Agent tool rather than executing steps sequentially inline. This is non-negotiable — treat it with the same weight as the no-commit rule above.
- **Never execute plan steps sequentially in the main conversation when they can be parallelized.** Identify independent tasks in the plan and dispatch them as concurrent subagents. Only execute steps inline when they have direct dependencies on prior steps that cannot be resolved by a subagent.

## Autonomy Boundaries

These are **hard requirements**, not suggestions:

- Do NOT auto-run validation (e.g., Nix builds, full test suites) after small config edits unless explicitly asked.
- Do NOT post comments on GitHub PRs. If feedback is needed, surface it in chat for the user to post.
- Do NOT create PRs unless explicitly told to; when asked, default to `--draft` unless told otherwise.
- Do NOT advance to the next phase of a multi-phase plan until the user confirms the previous phase is validated.

## Git Worktree Workflow

I use **worktrunk** (`wt`) for all worktree management. **Never use raw `git worktree` commands** — always use `wt`.

- The parent directory (e.g., `fw_monorepo/`) is a container — NOT a git directory
- The primary worktree is the default branch (e.g., `fw_monorepo/develop`)
- Feature worktrees are siblings named `<primary-dir>.<sanitized-branch>` — e.g. branch `feat/my-feature` lives at `fw_monorepo/develop.feat-my-feature`. This is worktrunk's default `{{ repo }}.{{ branch | sanitize }}` template, where `{{ repo }}` is the primary worktree's dir name and `/` in branch names becomes `-`.

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
