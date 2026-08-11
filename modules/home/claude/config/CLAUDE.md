@RTK.md

# Claude Code Configuration (Nix-Managed)

This Claude Code installation is declaratively managed via Nix home-manager.
Configuration files are read-only — do NOT attempt to write to `~/.claude/settings.json` directly.
Guide the user to edit the Nix config files in their dotfiles repo rather than writing directly.

## Git

- **Never run `git commit` (or anything that finalizes a commit).** I use a Yubikey for GPG commit signing which requires physical touch and does not work with automated commits. Staging is fine — `git add`, `git mv`, `git rm`, etc. are all okay to use, including as part of a file reorganization. Just don't commit; report what changed and let me review and commit myself.

## Bash

- **Never use a bare `~` in a variable assignment value** (e.g. `F=~/path`). Bash expands the tilde at assignment time, which trips a safety warning on every such command. Use `F="$HOME/path"` or an absolute path instead — identical behavior, no prompt.
- **Don't bundle a mutating segment into an otherwise-allowlisted chain.** Chaining is *not* itself a problem: verified empirically, `cd <path> && pnpm typecheck`, `pnpm … 2>&1 | tail -40`, `cmd > file`, and `mkdir -p … && cmd` all auto-approve as long as each segment is either allowlisted or a built-in read-only command (`head`, `tail`, `wc`, `grep`, `cd`, `echo`, …). What forces a prompt for the whole chain is one segment that matches nothing: `rm -f` / `rm -rf`, `touch`, `npm pack`, an unpinned `pnpm dlx <pkg>`, or a relative `node_modules/.bin/<bin>` path. Split *those* into their own call (or drop them — a temp-file cleanup is rarely worth a prompt); don't reflexively unbundle a chain that would have run fine.
  - **When a chain does prompt, diagnose the offending segment, don't guess.** Both this file and a prior session previously blamed the `cd …` prefix; that was wrong, and the wrong fix got adopted for weeks. Read `~/.claude/settings.json` and check each segment against `permissions.allow` / `permissions.deny` before concluding.
- **Never use `node -e`, `python -c`, or similar to inspect files or config.** Arbitrary code execution can't be allowlisted (it's the escape hatch the `pnpm exec node`/`sh` denies exist to block), so it prompts every time. To read `package.json` scripts, lockfiles, or any file, use the Read tool — that's what Project Command Discovery already requires.
- **Invoke project binaries via an allowlisted form, not a relative path.** Use `pnpm exec eslint …` / `npx eslint …` / `pnpm exec tsc …`, never `../node_modules/.bin/eslint …`. Relative `.bin/` paths match no allow pattern and prompt; the `pnpm exec <bin>` / `npx <bin>` forms are explicitly allowlisted.
- **Scratch files go in the session scratchpad, never bare `/tmp`.** Writing or deleting under `/tmp`, `/private/tmp`, or any ad-hoc absolute path falls outside the sandbox write scope and prompts. Use the scratchpad directory given in the system prompt, or `D="$TMPDIR/<name>"; mkdir -p "$D"`. This is the single most common cause of denied commands in the history — `npm pack` in `/tmp` was denied three times in a row and only went through once it ran in `$TMPDIR/nextcm`; a `tsc --generateTrace` run was denied writing `/private/tmp/tsc-trace` and accepted writing the scratchpad. Scoping the directory correctly also removes most reasons to reach for `rm -f` cleanup, which is separately denied.
- **Before proposing a new `Bash(...)` allow rule, run `rtk rewrite "<cmd>"` first.** Exit 0 or 3 means rtk rewrites the command to an `rtk …` form that the existing `Bash(rtk *)` entry already covers, so the new rule would be dead weight on arrival. Only exit 1 — no RTK equivalent — is a genuine allowlist gap. A 2026-08-10 audit proposed 10 patterns and this one check eliminated 7 of them (`git -C`, `curl`, `npx jest`, `pnpm exec turbo`/`prettier`/`prisma validate`).

## GitHub

- **Never post comments, reviews, or replies on GitHub PRs or issues on my behalf.** Read-only operations (viewing PRs, diffs, checks, comments) are fine. Creating PRs is allowed when asked. All other write operations (commenting, reviewing, closing, merging, editing) require explicit instruction.

## Inclusive Language

- **Never infer or assign gender to anyone whose gender has not been explicitly stated.** Do not guess from a name, GitHub username, email, photo, or any other indirect signal. Assuming gender from names perpetuates bias in the tech industry.
- Use `they`/`them`/`their` or the person's name/handle directly. Applies to PR reviewers, commit authors, teammates, ticket commenters, customers in logs, and any other third party in PR summaries, code-history narration, ticket triage, status updates, postmortems, etc.
- If you catch yourself having used `he`/`she` for someone whose gender wasn't stated, silently restate the relevant passage with neutral language and move on — no apology theater.

## Communication Style

- **During iterative work (reading files, running commands, searching), stay terse.** Do not narrate each step ("Now let me…", "That confirms…, next I'll…"). Work through the steps and report at decision points, not between every tool call.
- **Speak when it earns attention:** a completed unit of work with a result or finding, a blocker needing input, or a genuine decision point (as already defined by the Scope, investigate, and commit-boundary rules below). Otherwise, work quietly.
- This lowers output-token cost and keeps signal high. It does NOT relax any decision-point communication the other sections require.

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

## Dev Artifact Storage

These are **hard requirements**, not suggestions:

- **Non-committed dev artifacts go in `<repo-root>/docs/local/`, never elsewhere under `docs/`.** Plans, design docs, QA checklists, PR/code reviews, error-triage reports, analytics/regression/consolidated write-ups, dead-code surveys — anything I generate as a working artifact rather than product documentation — is a dev artifact. Write it under `docs/local/<area>/` at the repo root, keeping the existing per-area subfolders:

  | Area | Path |
  |---|---|
  | Plans / design docs / QA | `docs/local/plans/` |
  | PR & code reviews | `docs/local/reviews/` |
  | Error triage | `docs/local/error-triage/` |
  | Analytics friction | `docs/local/analytics/` |
  | Regression analysis | `docs/local/regressions/` |
  | Consolidated analysis | `docs/local/consolidated/` |
  | Dead-code surveys | `docs/local/dead-code/` |

- **`docs/local/` is git-ignored** (`**/docs/local/` in the repo's `.gitignore`) so these never get committed. Create the directory if it does not exist; never `git add`/`commit` anything under it — version control of a dev artifact is my explicit call, not the default.
- **Real product documentation still belongs in `docs/`** and is committed as normal. The distinction is intent: a throwaway working artifact → `docs/local/`; documentation meant to ship with the repo → `docs/`.
- If a repo has **no `.gitignore` entry** for `**/docs/local/` yet, add one as part of the first artifact write in that repo (and tell me), so the folder stays uncommitted.

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

- **The commit boundary is the stop, and the user owns the commit.** Since the user GPG-signs every commit by hand (Yubikey touch) and you never commit, each commit-sized chunk — a phase in a `feature-plan`, or an agreed chunk in ad-hoc work — is a mandatory hand-back: build the chunk, report the files changed, then STOP and wait for the user to review and commit before starting the next chunk. Never stack a second chunk's changes onto an uncommitted one — that buries the review and breaks the one-commit-per-phase cadence. Treat a plan's `MANUAL REVIEW CHECKPOINT` / `STOP here` markers as control flow, not narration. Do not invent extra stops between agreed boundaries, and do not run past them — the cadence was agreed at planning time; execution honors it, it does not renegotiate it.
- **Always use subagent-driven development when executing implementation plans.** Delegate independent tasks to subagents via the Agent tool rather than executing steps sequentially inline. This is non-negotiable — treat it with the same weight as the no-commit rule above.
- **Fan out within a chunk, halt at its boundary.** Subagent parallelism applies to independent tasks inside the current phase only; it never licenses crossing into the next commit. Only execute steps inline when they have direct dependencies on prior steps that cannot be resolved by a subagent.
- **At the same hand-back stop, before starting the next phase, run two cheap pre-phase checks.** Both piggyback on the mandatory pause above — neither is a reason to add an extra stop of its own:
  - **Compaction check:** note in one line whether context is large enough that compacting now (before the next phase) would help more than compacting mid-phase, and say so — don't just compact silently or wait to be asked.
  - **Stale-assumption check:** re-check the specific assumptions the next phase's plan text depends on — the sections it cites, the repo/user state it presumes — against what's actually true now. This is targeted, not a full plan re-audit: check only what the upcoming phase leans on. Surface any drift found before proceeding, the same way code that predates a later convention gets flagged rather than silently trusted (see dotfiles `CONVENTIONS.md`'s "config drift" section for the code-side version of this same failure mode). A plan phase built on a premise the user has since corrected is exactly the kind of cascading rework this check exists to catch early.

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

**Exception — the `dotfiles` repo itself does not use worktrees.** Work directly in `~/dotfiles`; do not create a worktree for dotfiles changes. Many of its home-manager modules deploy config through `config.lib.file.mkOutOfStoreSymlink` against a hardcoded `${config.home.homeDirectory}/dotfiles/...` path (see `modules/home/ghostty/default.nix`, `modules/home/karabiner/default.nix`, `modules/home/aerospace/default.nix`). A rebuild from a worktree therefore points `~/.config/*` back at the *primary* checkout, so config added on the branch never resolves and cannot be tested until it merges. The symlink stitching requires the real path.

### Moving a session into a new worktree mid-session

A session is anchored to the directory `claude` launched in; `wt switch` inside a Bash tool call runs in a subshell and cannot move it, so the conversation history and memory stay on the branch you started on. If you create a worktree partway through a session and want to keep the current conversation, run `/cd <new-worktree-path>` from the existing session — it relocates the session to the new worktree's project storage so the history follows. (`/branch` forks in the same directory and resume always re-anchors to the original directory; neither moves the session. `/cd` requires Claude Code v2.1.169+.)

Prefer creating the worktree *before* launching `claude` when the work is planned — the worktrunk `post-switch` hook already spawns a fresh session in the new worktree. Use `/cd` for the mid-thought pivot case.

### Memory across worktrees

Claude's per-project memory directory (`~/.claude/projects/<encoded-cwd>/memory/`) is keyed by the working directory, so each worktree gets its own isolated memory. Memories saved in a feature worktree's directory disappear when that worktree is removed and are invisible from sibling worktrees.

**Rule:** When saving project- or repo-wide memory (e.g., `project` or `feedback` types that apply beyond the current task), write it to the **default-branch worktree's** memory directory, not the current feature worktree's. For AdminPortal that's `~/.claude/projects/-Users-fw-skylerlemay-code-work-AdminPortal-develop/memory/`. Use the current worktree's memory only for memories scoped to the in-progress branch work that won't be relevant after the branch merges.
