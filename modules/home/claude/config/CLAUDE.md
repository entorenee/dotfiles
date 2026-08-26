# Claude Code Configuration (Nix-Managed)

This installation is declaratively managed by Nix home-manager. `~/.claude/` config files are
read-only — never write `settings.json` or similar directly. Point me at the Nix source in
`~/dotfiles` instead.

**Everything below is a hard requirement, not a suggestion.**

## Git

- **Never run `git commit`**, or anything that finalizes one. I GPG-sign with a Yubikey, which
  needs a physical touch and cannot be automated. Report what changed; I commit.
- **Never run `git add` — leave every edit unstaged.** The staging area is my review marker: a
  staged file means *I* have read it. Staging on my behalf marks work reviewed when it is not.
  If something is already staged, `git restore --staged <paths>` unstages it without touching
  the working tree.
- **`git mv` is the one deliberate exception.** Use it for renames so the rename is recorded and
  the new path never sits untracked; it stages, and that trade is intended. For deletions use
  plain `rm`, which leaves an unstaged deletion.

## Bash

- **Never a bare `~` in a variable assignment value** (`F=~/path`). Tilde expansion at assignment
  time trips a safety warning on every such command. Use `F="$HOME/path"` or an absolute path.
- **Chaining is fine; one unmatched segment is not.** `cd <path> && pnpm typecheck`,
  `pnpm … | tail -40`, `cmd > file`, and `mkdir -p … && cmd` all auto-approve as long as every
  segment is allowlisted or a read-only builtin (`head`, `tail`, `wc`, `grep`, `cd`, `echo`, …).
  What prompts is a segment matching nothing: `rm -f`/`rm -rf`, `touch`, `npm pack`, an unpinned
  `pnpm dlx <pkg>`, or a relative `node_modules/.bin/<bin>` path. Split those into their own
  call; don't reflexively unbundle a chain that would have run fine.
- **Diagnose a prompt; never guess at it.** `cd` has been wrongly blamed for this before and the
  wrong fix stuck for weeks. A correct diagnosis needs both halves: check each segment against
  `permissions.allow`/`permissions.deny` in `~/.claude/settings.json`, **and** run
  `rtk rewrite "<cmd>"` for its exit code. Either half alone has produced a wrong answer.
- **rtk rewrites commands before they run, and decides their permission.** A `PreToolUse` hook
  (`~/.claude/hooks/rtk-rewrite.sh`) pipes every Bash command through `rtk rewrite`, so
  `git status` transparently becomes `rtk git status`. The exit code is the decision: `0`
  rewrites and returns `permissionDecision: "allow"`, bypassing allow/deny matching entirely;
  `3` rewrites and lets Claude Code prompt; `1` and `2` pass the command through untouched, so
  `permissions.deny` handles it natively. `Bash(rtk proxy*)` is denied — arbitrary-command
  escape hatch.
- **Before proposing any new `Bash(...)` allow rule, run `rtk rewrite "<cmd>"` first.** Exit 0
  or 3 means the existing `Bash(rtk *)` entry already covers it and the new rule is dead weight
  on arrival. Only exit 1 — no rtk equivalent — is a genuine gap. This one check eliminated 7 of
  10 proposed patterns in a single audit.
- **Never `node -e`, `python -c`, or similar to inspect files or config.** Arbitrary code
  execution can't be allowlisted — it is the escape hatch the `pnpm exec node`/`sh` denies exist
  to block — so it prompts every time. Read files with the Read tool.
- **Invoke project binaries through an allowlisted form**, not a relative path: `pnpm exec
  eslint …`, `npx eslint …`, `pnpm exec tsc …`, never `../node_modules/.bin/eslint …`.
- **Scratch files go in the session scratchpad or `$TMPDIR`, not bare `/tmp`.** Use the
  scratchpad named in the system prompt, or `D="$TMPDIR/<name>"; mkdir -p "$D"`. This is not
  about write access — `/tmp` and `/private/tmp` are both in `sandbox.filesystem.allowWrite`
  (check with `jq -r '.sandbox.filesystem.allowWrite[]'`). It keeps scratch out of a shared
  namespace.

## GitHub

- **Never post comments, reviews, or replies on PRs or issues on my behalf.** Read-only
  operations (viewing PRs, diffs, checks, comments) are fine, and creating PRs is fine when
  asked. Every other write — commenting, reviewing, closing, merging, editing — needs explicit
  instruction.

## Inclusive Language

- **Never infer gender from a name, username, email, photo, or any other indirect signal.** Use
  `they`/`them` or the person's name/handle. Applies to PR reviewers, commit authors,
  teammates, ticket commenters, customers in logs — in PR summaries, code-history narration,
  triage, status updates, postmortems, anywhere.
- If you catch yourself having used `he`/`she` for someone whose gender wasn't stated, silently
  restate the passage neutrally and move on — no apology theater.

## Communication Style

- **During iterative work — reading files, running commands, searching — stay terse.** Do not
  narrate each step ("Now let me…", "That confirms…, next I'll…"). Report at decision points,
  not between every tool call.
- **Speak when it earns attention:** a completed unit of work with a result, a blocker needing
  input, or a genuine decision point. Otherwise work quietly. This does NOT relax any
  decision-point communication the sections below require.

## Nix / Environment

- CLI tools, dev dependencies, and system config are managed via Nix home-manager. Never suggest
  Homebrew for CLI tools. **Exception:** macOS GUI apps (casks) should use Homebrew, since Nix
  does not manage macOS UI apps well.
- `/nix/store` is read-only — never attempt writes there.
- Prefer native home-manager modules (`programs.claude-code`, `programs.git`, `programs.zsh`)
  over custom activation scripts, manual JSON edits, or raw `home.packages` entries.
- For MCP servers, update the identity file the machine imports —
  `hosts/darwin/fw-skyler/claude.nix` for work, `roles/home/personal-claude.nix` for personal.
  Fall back to `claude mcp add` only for quick testing.
- **Do not auto-run `@nix-validator` after a Nix edit.** For a small edit run a plain `nix eval`
  on the affected host attribute and report it — cheap and falsifiable. Reach for the full
  validator only at a commit boundary, and say you are doing it.

## Project Command Discovery

Before running any build, test, lint, typecheck, format, or package-manager command, discover
the project's actual conventions. Do not guess from defaults (`npm test`, `npm run lint`) —
guessing wastes attempts and pollutes diffs.

1. **Read `package.json`** at the repo root and use the exact script names defined there:
   - typecheck: often `typecheck`, `tsc`, `type-check` — sometimes only via the orchestrator
   - lint: prefer a non-mutating variant (`lint:ci`, `lint:check`) over `lint`/`lint:fix`
   - test: prefer `test:ci`; build: prefer `build:ci` — CI variants are deterministic
2. **Detect the package manager** from the root lockfile: `pnpm-lock.yaml` → pnpm, `yarn.lock` →
   yarn, `bun.lockb` → bun, `package-lock.json` → npm. Never default to npm when another
   lockfile is present.
3. **Detect orchestrators:** `turbo.json` → `<pm> turbo <task>`, preferring
   `--filter='...[<merge-base>]'`. `nx.json` → `nx affected`. `lerna.json`,
   `pnpm-workspace.yaml` → respect workspace boundaries.
4. **Read the nearest `CLAUDE.md`** — repo root first, then any closer to the files you're
   editing. Its documented conventions (logging helpers, error wrappers, banned APIs, import
   aliases, test patterns) override generic defaults.
5. **Non-JS projects:** read `Cargo.toml`, `pyproject.toml`/`uv.lock`, `go.mod`, `Gemfile`,
   `mix.exs`, plus any `Makefile`/`justfile`, and use those canonical commands.

**When delegating to subagents, pass the discovered commands verbatim.** Subagents do not
inherit your discovery — told to "run the tests," they will guess.

**Without access to `package.json`** (e.g. running above the project root): say so explicitly
and ask before running anything. Do not fall back to defaults.

## Dev Artifact Storage

Plans, design docs, QA checklists, PR/code reviews, error-triage reports, analytics and
regression write-ups, dead-code surveys — anything generated as a working artifact rather than
product documentation — live outside the repo in `$ARTIFACTS/<area>/`. Resolve the root once per
session:

```bash
ARTIFACTS="${MY_CLAUDE_ARTIFACTS_ROOT:?run 'make rebuild', then start a new session}/$(basename -s .git \
  "$(git remote get-url origin 2>/dev/null || git rev-parse --show-toplevel)")"
mkdir -p "$ARTIFACTS/<area>"
```

`MY_CLAUDE_ARTIFACTS_ROOT` is injected by `modules/home/claude/default.nix` — never hardcode the
path here or in a skill. The `:?` is deliberate: an unset root should stop you, not quietly
write to `/<repo>/<area>/`. Keying on the **remote name** is what makes this worktree-proof —
every worktree resolves to the same directory, so an artifact written on a feature branch is
readable from siblings and survives `wt remove`. The `rev-parse` fallback covers a repo with no
remote.

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

- **Registers are keyed by branch, not date**, and are read before work rather than written
  after it. `/` in the branch name becomes `-`, matching worktrunk. See the `domain-register`
  skill for the three states and the graduation rule.
- **Print the absolute path when you write one.** These are outside the editor tree, so an
  unannounced artifact is an invisible one.
- **Real product documentation still belongs in `docs/`** and is committed as normal. The
  distinction is intent: throwaway working artifact → `$ARTIFACTS/`; docs meant to ship → `docs/`.
- **`<repo-root>/docs/local/` is the retired location.** Read what's there, but say so rather
  than writing anything new alongside it.

## Scope & Approach

- **State what a proposal rests on, before proposing it.** Name the load-bearing assumptions and
  mark each `verified` / `inferred` / `assumed`, so a wrong premise can be rejected once instead
  of the conclusion three times. An `inferred` or `assumed` premise that would change the
  recommendation if false gets checked *before* building, not after.
- **For pure lookups ("where is X?"), return the answer only.** A question about where something
  lives is not authorization to change it.
- **Remove obsolete logic rather than layering new code beside it.** When a change supersedes
  existing logic, delete the old path in the same change unless told otherwise. Never leave both
  alive.
- **Do not expand scope or bundle out-of-scope work into a commit without approval.** If you find
  adjacent work worth doing, name it and ask.
- **Route bug, test-failure, and unexpected-behavior investigations through the `investigate`
  skill** before proposing a fix. It adds the gates this file cannot — batched intake, the branch
  register, existing-test analysis, and a mandatory stop before any fix.

## Code Review & Diagnosis

- **Never label a finding "Critical" or assert a root cause without evidence from the actual
  code.** Quote the exact diff line or error message, and rate severity only on what is literally
  present in the changed code — never on an agent's summary, a theory, or an assumption.
- **Verify every subagent finding against the real diff before relaying it.** Agent summaries
  overstate; downgrade or drop anything you cannot ground in the actual change.

## Verification

- **After code changes, run typecheck, lint, and tests, and report pass/fail per check** before
  claiming completion. Use the commands from Project Command Discovery — do not guess them.
- **If a worktree is missing the binaries to verify** (broken symlink, uninstalled deps), say so
  explicitly and report what could not be run. Never silently skip verification and imply it
  passed.

## Plan Execution

- **The commit boundary is the stop, and I own the commit.** Each commit-sized chunk — a
  `feature-plan` phase, or an agreed chunk in ad-hoc work — is a mandatory hand-back: build it,
  report the files changed, then STOP and wait for me to review and commit. Never stack a second
  chunk onto an uncommitted one; that buries the review. Treat `MANUAL REVIEW CHECKPOINT` /
  `STOP here` markers as control flow, not narration. Do not invent extra stops between agreed
  boundaries, and do not run past them.
- **Always use subagent-driven development when executing implementation plans.** Delegate
  independent tasks via the Agent tool rather than working through steps inline. Non-negotiable,
  same weight as the no-commit rule. Work inline only where a step has a direct dependency on a
  prior one that a subagent cannot resolve.
- **Fan out within a chunk, halt at its boundary.** Parallelism applies inside the current phase
  only; it never licenses crossing into the next commit.
- **At that same hand-back stop, run two cheap pre-phase checks** — both piggyback on the pause,
  neither justifies an extra stop of its own:
  - **Compaction check:** note in one line whether compacting now would help more than
    compacting mid-phase. Don't compact silently or wait to be asked.
  - **Stale-assumption check:** re-check the specific assumptions the next phase leans on — the
    sections it cites, the repo/user state it presumes — against what's true now. Targeted, not
    a full re-audit. A phase built on a premise I've since corrected is exactly the cascading
    rework this catches.

## Autonomy Boundaries

- Do NOT auto-run validation (Nix builds, full test suites) after small config edits unless asked.
- Do NOT post comments on GitHub PRs. Surface feedback in chat for me to post.
- Do NOT create PRs unless told to; when asked, default to `--draft`.
- Do NOT advance to the next phase of a multi-phase plan until I confirm the previous one.

## Git Worktree Workflow

I use **worktrunk** (`wt`) for all worktree management. **Never use raw `git worktree`
commands.** The parent directory (e.g. `fw_monorepo/`) is a container, not a git directory; the
primary worktree is the default branch (`fw_monorepo/develop`); feature worktrees are siblings
named `<primary-dir>.<sanitized-branch>`, so `feat/my-feature` lives at
`fw_monorepo/develop.feat-my-feature` (`/` becomes `-`).

```bash
wt switch --create feat/my-feature       # new branch from default branch
wt switch --create fix/bug-name --base @ # new branch from current HEAD
wt switch feat/my-feature                # switch to existing worktree
wt switch -                              # previous worktree
wt switch ^                              # default branch worktree
wt list                                  # show all worktrees
wt remove                                # remove current; deletes branch if merged
```

Branch names must start with a conventional-commit prefix: `fix/`, `feat/`, `docs/`, `chore/`,
`refactor/`, `test/`, `perf/`, `ci/`.

- **All feature work, bug fixes, and implementation tasks use a worktree.** Create one
  proactively without asking.
- **Exception — the `dotfiles` repo does not use worktrees.** Work directly in `~/dotfiles`.
  Many of its home-manager modules deploy config via `config.lib.file.mkOutOfStoreSymlink`
  against a hardcoded `${config.home.homeDirectory}/dotfiles/...` path (see `modules/home/`
  `ghostty`, `karabiner`, `aerospace`). A rebuild from a worktree points `~/.config/*` back at
  the *primary* checkout, so branch config never resolves and can't be tested until it merges.

### Moving a session into a new worktree mid-session

A session is anchored to the directory `claude` launched in; `wt switch` inside a Bash call runs
in a subshell and cannot move it. To keep the current conversation, run `/cd <new-worktree-path>`
— it relocates the session so history follows. (`/branch` forks in the same directory, and
resume re-anchors to the original; neither moves the session.) Prefer creating the worktree
*before* launching `claude` when work is planned; use `/cd` for the mid-thought pivot.

The worktrunk `post-switch` hook does not start a session — its two hooks are
`modules/home/worktrunk/hooks/tmux-switch.sh` (tmux window and panes) and `pnpm-warm.sh`
(detached install).

### Memory across worktrees

Auto memory is keyed by **git repository**, not working directory, so every worktree of a repo
shares one memory directory and memories survive `wt remove`. No worktree-specific handling is
needed. Session transcripts are still per-directory.
