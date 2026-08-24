# Claude Code Configuration (Nix-Managed)

This Claude Code installation is declaratively managed via Nix home-manager.
Configuration files are read-only — do NOT attempt to write to `~/.claude/settings.json` directly.
Guide the user to edit the Nix config files in their dotfiles repo rather than writing directly.

## Git

- **Never run `git commit` (or anything that finalizes a commit).** I use a Yubikey for GPG commit signing which requires physical touch and does not work with automated commits. Report what changed and let me review and commit myself.
- **Never run `git add` either — leave every edit unstaged.** I use the staging area as my own review marker: a staged file means *I* have read it. Staging on my behalf destroys that signal and marks work reviewed when it is not. Finish the edits, say which files changed, and stop. If something is already staged, `git restore --staged <paths>` unstages it without touching the working tree.
- **`git mv` is the one exception, and it is deliberate.** Use it for renames instead of plain `mv`, so the rename is recorded rather than left to git's similarity detection and the new path never sits untracked. It does stage the change — that is the trade I want here. For deletions use plain `rm`: the file goes away and git reports an unstaged deletion, so nothing is marked reviewed on my behalf.

## Bash

- **Never use a bare `~` in a variable assignment value** (e.g. `F=~/path`). Bash expands the tilde at assignment time, which trips a safety warning on every such command. Use `F="$HOME/path"` or an absolute path instead — identical behavior, no prompt.
- **Don't bundle a mutating segment into an otherwise-allowlisted chain.** Chaining is *not* itself a problem: verified empirically, `cd <path> && pnpm typecheck`, `pnpm … 2>&1 | tail -40`, `cmd > file`, and `mkdir -p … && cmd` all auto-approve as long as each segment is either allowlisted or a built-in read-only command (`head`, `tail`, `wc`, `grep`, `cd`, `echo`, …). What forces a prompt for the whole chain is one segment that matches nothing: `rm -f` / `rm -rf`, `touch`, `npm pack`, an unpinned `pnpm dlx <pkg>`, or a relative `node_modules/.bin/<bin>` path. Split *those* into their own call (or drop them — a temp-file cleanup is rarely worth a prompt); don't reflexively unbundle a chain that would have run fine.
  - **When a chain does prompt, diagnose the offending segment, don't guess.** Both this file and a prior session previously blamed the `cd …` prefix; that was wrong, and the wrong fix got adopted for weeks. Read `~/.claude/settings.json` and check each segment against `permissions.allow` / `permissions.deny` before concluding.
- **Never use `node -e`, `python -c`, or similar to inspect files or config.** Arbitrary code execution can't be allowlisted (it's the escape hatch the `pnpm exec node`/`sh` denies exist to block), so it prompts every time. To read `package.json` scripts, lockfiles, or any file, use the Read tool — that's what Project Command Discovery already requires.
- **Invoke project binaries via an allowlisted form, not a relative path.** Use `pnpm exec eslint …` / `npx eslint …` / `pnpm exec tsc …`, never `../node_modules/.bin/eslint …`. Relative `.bin/` paths match no allow pattern and prompt; the `pnpm exec <bin>` / `npx <bin>` forms are explicitly allowlisted.
- **Scratch files go in the session scratchpad or `$TMPDIR`, not bare `/tmp`.** Use the scratchpad directory named in the system prompt, or `D="$TMPDIR/<name>"; mkdir -p "$D"`. The harness itself instructs this — `$TMPDIR` is set to the correct sandbox-writable directory — and a session-scoped directory keeps scratch out of a shared namespace.
  - **The reason is *not* write access.** `/tmp` and `/private/tmp` are both in `sandbox.filesystem.allowWrite` on every identity and in the live `settings.json` — check with `jq -r '.sandbox.filesystem.allowWrite[]'`. The preference above is about keeping scratch out of a shared namespace.
  - **What actually caused the recorded denials was the command, not the path.** `npm pack` and `rm -f` match no allow pattern (see the bundling bullet above, which names both), so they prompt wherever they run. Moving them to `$TMPDIR` also happened to drop the `rm -f` cleanup, which is what made the difference. Diagnose a denial by checking the command against `permissions.allow`/`deny`, not by assuming the directory.
- **rtk rewrites commands before they run, and it also decides their permission.** A `PreToolUse` hook (`~/.claude/hooks/rtk-rewrite.sh`) pipes every Bash command through `rtk rewrite`; `git status` becomes `rtk git status`, transparently. **The exit code is the decision**, which is why it matters here: `0` rewrites and returns `permissionDecision: "allow"`, bypassing allow/deny matching entirely; `3` rewrites and lets Claude Code prompt; `1` and `2` pass the command through untouched, so `permissions.deny` handles it natively. Measured 2026-08-21 with `rtk gain`: 1077 commands, 6.8M tokens saved, 78.4%. `Bash(rtk proxy*)` is denied — it is an arbitrary-command escape hatch.
- **So when diagnosing why a command prompted, `settings.json` is necessary but not sufficient.** For anything rtk rewrites, the effective decision came from the hook, not the allowlist. Run `rtk rewrite "<cmd>"` and read its exit code alongside the allow/deny check above; the two together are the whole answer, and either alone has produced a wrong diagnosis before.
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
- For MCP server configuration, prefer updating the identity file the machine imports — `hosts/darwin/fw-skyler/claude.nix` for work, `roles/home/personal-claude.nix` for personal — for deterministic, reproducible config. Fall back to `claude mcp add` only for quick testing.
- **Do not auto-run `@nix-validator` after a Nix edit.** For a small edit, run a plain `nix eval` on the affected host attribute and report it — that is cheap and falsifiable. Reach for the full validator only at a **commit boundary**, which is already a defined stop, and say you are doing it.

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

- **Dev artifacts live outside the repo, in `$ARTIFACTS/<area>/`.** Plans, design docs, QA checklists, PR/code reviews, error-triage reports, analytics/regression/consolidated write-ups, dead-code surveys — anything I generate as a working artifact rather than product documentation — is a dev artifact. Resolve the root once per session:

  ```bash
  ARTIFACTS="${MY_CLAUDE_ARTIFACTS_ROOT:?run 'make rebuild', then start a new session}/$(basename -s .git \
    "$(git remote get-url origin 2>/dev/null || git rev-parse --show-toplevel)")"
  mkdir -p "$ARTIFACTS/<area>"
  ```

  `MY_CLAUDE_ARTIFACTS_ROOT` is injected by `modules/home/claude/default.nix` into both this session and the shell, so it is the one place the root is written down — never hardcode the path here or in a skill. The `:?` is deliberate: an unset root should stop you, not quietly write to `/<repo>/<area>/`.

  Keying on the **remote name** is what makes this worktree-proof: every worktree of `fw_monorepo` resolves to the same `fw_monorepo` directory, so an artifact written from a feature branch is readable from every sibling and survives `wt remove`. The `rev-parse` fallback covers a repo with no remote.

  | Area | Path |
  |---|---|
  | Plans / design docs / QA | `$ARTIFACTS/plans/` |
  | PR & code reviews | `$ARTIFACTS/reviews/` |
  | Error triage | `$ARTIFACTS/error-triage/` |
  | Analytics friction | `$ARTIFACTS/analytics/` |
  | Regression analysis | `$ARTIFACTS/regressions/` |
  | Consolidated analysis | `$ARTIFACTS/consolidated/` |
  | Dead-code surveys | `$ARTIFACTS/dead-code/` |
  | Release notes / changelogs | `$ARTIFACTS/changelogs/` |
  | Domain-assumption registers | `$ARTIFACTS/registers/<branch>.md` |

  **Registers are keyed by branch, not by date**, and are the one area that is read
  before work rather than written after it. `/` in the branch name becomes `-`, matching
  worktrunk. See the `domain-register` skill for the three states and the graduation
  rule; the branch keying plus remote-name resolution is what lets a register written on
  a feature branch be read from a sibling worktree and survive `wt remove`.

- **Print the absolute path when you write one.** They are no longer in the editor tree, so an unannounced artifact is an invisible one.
- **Real product documentation still belongs in `docs/`** and is committed as normal. The distinction is intent: a throwaway working artifact → `$ARTIFACTS/`; documentation meant to ship with the repo → `docs/`.
- **Nothing about this is git-managed**, which is the point — no `.gitignore` entry to add per repo, nothing that can be committed by accident, nothing that a worktree removal or a `docs/local` cleanup can destroy.
- **`<repo-root>/docs/local/` is the retired location.** Artifacts there predate the move; read them, and say so rather than writing anything new alongside them.

## Scope & Approach

These are **hard requirements**, not suggestions:

- **For pure lookups ("where is X?"), return the answer only — do not begin changes.** A question about where something lives is not authorization to alter it.
- **Remove obsolete logic rather than layering new code beside it.** When a change supersedes existing logic (e.g. replacing a text-based check with a status-code check), delete the old path in the same change unless told to keep it. Do not leave both alive.
- **Do not expand scope or bundle out-of-scope work into a commit without explicit approval.** If you discover adjacent work worth doing, name it and ask — do not fold it in.
- **Route bug, test-failure, and unexpected-behavior investigations through the `investigate` skill.** It adds the gates this file cannot — a batched intake, the branch register, existing-test analysis, and a mandatory stop before any fix — and invokes `superpowers:systematic-debugging` for the root-cause method itself. Invoke it before proposing a fix rather than debugging ad-hoc.

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

Prefer creating the worktree *before* launching `claude` when the work is planned, and launch the session there yourself. Use `/cd` for the mid-thought pivot case.

**The worktrunk `post-switch` hook does not start a session.** Its two hooks are `modules/home/worktrunk/hooks/tmux-switch.sh` (creates a tmux window and splits panes) and `pnpm-warm.sh` (detached install); nothing in that directory references `claude`.

### Memory across worktrees

Claude's per-project memory directory (`~/.claude/projects/<encoded-cwd>/memory/`) is keyed by the working directory, so each worktree gets its own isolated memory. Memories saved in a feature worktree's directory disappear when that worktree is removed and are invisible from sibling worktrees.

**Rule:** When saving project- or repo-wide memory (e.g., `project` or `feedback` types that apply beyond the current task), write it to the **default-branch worktree's** memory directory, not the current feature worktree's. For AdminPortal that's `~/.claude/projects/-Users-fw-skylerlemay-code-work-AdminPortal-develop/memory/`. Use the current worktree's memory only for memories scoped to the in-progress branch work that won't be relevant after the branch merges.
