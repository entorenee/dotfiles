---
description: Run pre-pr, auto-fix every finding a subagent can safely resolve, verify until green, then report only what still needs me.
argument-hint: [optional scope reference — Asana task, GH issue, or freeform]
---

# /pre-pr-autonomous

You are running an autonomous pre-PR pass. The user wants you to fix everything that can be fixed without their judgment, then surface only the residue. Speed matters — parallelize aggressively.

## Phase 0 — Project Command Discovery (do this FIRST, before anything else)

The pre-pr skill and the autonomous fix subagents will run real commands against this repo. They MUST use the project's actual scripts and conventions, not generic guesses. Before touching the skill:

1. **Read `package.json`** at the repo root. Capture the exact `scripts` keys for:
   - typecheck (commonly `typecheck`, `tsc`, `type-check`, sometimes only via `turbo`)
   - lint (commonly `lint`, `lint:ci`, `lint:fix` — prefer `lint:ci` if present; it's non-mutating)
   - test (commonly `test`, `test:ci`, `test:unit` — prefer `test:ci` if present)
   - build (commonly `build`, `build:ci`)
   - format (commonly `format`, `prettier`)
2. **Detect package manager** from lockfile: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lockb` → bun, `package-lock.json` → npm. Use this everywhere — never assume.
3. **Detect monorepo orchestrator**: `turbo.json` → turbo, `nx.json` → nx, `lerna.json` → lerna, `workspaces` field → workspaces. If turbo is present, prefer `<pm> turbo <task> --filter='...[<merge-base>]'` for affected-only runs.
4. **Read the nearest `CLAUDE.md`** (repo root first, then any closer to changed files). Capture any documented conventions for: logging helpers (e.g. `logError` vs `logger.error`), error wrappers, import paths, test patterns, banned APIs.
5. **Record the discovered values in a `PROJECT_COMMANDS` block** that you will pass verbatim into every subagent prompt. Example shape:

   ```
   PROJECT_COMMANDS:
   - package manager: pnpm
   - typecheck: pnpm typecheck
   - lint (non-mutating): pnpm lint:ci
   - lint (autofix): pnpm lint:fix
   - test: pnpm test:ci
   - monorepo: turbo (prefer `pnpm turbo <task> --filter='...[$MERGE_BASE]'` when scoping)
   - logging: use logError(err, ctx) from src/lib/log — never console.error or logger.error
   - banned: console.*, any 'as any' in src/**
   ```

If `package.json` does not exist (non-JS repo), record that and adapt: read the equivalent manifest (`Cargo.toml`, `pyproject.toml`, `go.mod`, etc.) and the project's Makefile/justfile for canonical commands.

**Do not skip Phase 0.** Every downstream step depends on it. If you proceed without it, subagents will run wrong commands and waste a fix attempt.

## Phase 1 — Run the pre-pr skill

Invoke the `pre-pr` skill via the Skill tool. Pass the user's argument (if any) as the scope reference. The skill produces a combined report with three sections: Code Hygiene (auto-fixed + needs review), Verification, Code Review.

Capture the full report output. You will categorize its findings next.

## Phase 2 — Categorize findings

Split every "Needs Your Review" / "Issues" item from the pre-pr report into two buckets:

### auto-fixable (a subagent can resolve without user input)
Mechanical or unambiguous fixes where the correct answer is determined by the code, the project conventions in `PROJECT_COMMANDS`, or the diff itself: stray artifacts and dead code, lint-autofixable rules, formatting drift, type errors with a single obvious fix, a banned API swapped for its documented replacement, and unit tests added to an *existing* suite for a *pure* function the diff fully specifies. `code-hygiene` owns the artifact classes — don't re-enumerate them here.

### needs-human-judgment (surface to user; do NOT dispatch)
Anything requiring product, design, or architectural judgment, or where the "fix" could plausibly be more than one thing. Examples:
- Scope deviations ("file X modified but not in ticket")
- Ambiguous TODOs ("// TODO: revisit — keep or remove?")
- New test files for behavior not fully specified by the diff
- Behavior changes flagged by the reviewer (correctness debates)
- Anything labeled Critical or Important by the code reviewer unless it's a pure mechanical fix
- Dependency upgrades or new dependencies
- Schema / migration changes
- Anything where you would need to ask the user "which of these did you mean"

**Rule of thumb:** if a competent engineer would resolve it in <2 minutes without asking anyone, it's auto-fixable. Otherwise it's human-judgment.

When in doubt, classify as human-judgment. The cost of surfacing too much is small; the cost of an autonomous wrong fix is large.

## Phase 3 — Dispatch parallel fix subagents

For each auto-fixable finding, dispatch one Task subagent. **All subagents in a single message** — they run concurrently.

Each subagent prompt MUST include, verbatim:
1. The `PROJECT_COMMANDS` block from Phase 0
2. The specific finding to fix (file path, line number, exact issue text)
3. **Scope clamp**: "Modify only the file(s) named in this finding. Do not touch unrelated code. Do not run typecheck/lint/test — the orchestrator does that after all subagents return."
4. **Verification clamp**: "After editing, re-read the file to confirm the change is correct. Report back: file(s) modified, what changed, any unexpected obstacles."
5. **Convention enforcement**: "Use exactly the commands and conventions in PROJECT_COMMANDS. If you would have run `npm` or `console.error` or `logger.error`, stop and use the documented replacement."
6. **Falsification clamp** (any finding whose fix adds or edits a test): "A new test is not done until it has failed. Run it against the pre-fix implementation — `git stash` your change, or point the import at `git show HEAD:<file>` — and confirm it **fails** for the right reason. Report the falsification result next to the pass. If it passes both before and after, it pins nothing; say so instead of reporting it as coverage."
7. **Evidence clamp**: "Quote the exact line that justifies your fix. If you cite a schema default, a field being unused, or a lifecycle guarantee, you must have read it in the file — not inferred it from a name or a nearby model."

Use `subagent_type: general-purpose` unless the finding clearly matches a specialized agent. Pass `description` as a short label so it's identifiable in the dispatch list.

Wait for all subagents to return. Collect their reports.

**Subagent output is unverified input, not results.** Before any of it reaches your report:

- **Re-derive every count yourself.** Test totals, error counts, files-changed — read them from the command output you ran in Phase 4, never from a subagent's summary. A relayed count has been wrong in practice.
- **Re-ground every factual claim** a subagent used to justify its fix, by opening the file and quoting the line. Claims of the form "field X has default Y", "variable Z is unused", or "callback W always fires" have all been fabricated. If the claim fails but the fix is still right, keep the fix and **correct the stated reason** — a right fix with a wrong rationale gets deleted by the next reader who checks it.

## Phase 4 — Verify, iterate up to 3 times

Once subagents have returned, run the verification commands **in parallel** (separate Bash tool calls in a single message), using the exact scripts from `PROJECT_COMMANDS`:

- typecheck
- lint (the non-mutating variant — `lint:ci` if it exists, else plain `lint`)
- test (`test:ci` if it exists, else plain `test`)

### Exit codes must come from the command, never through a pipe

**A pipeline reports the status of its *last* command, not the one you care about.** `cmd | tail -15` gives you `tail`'s status — and `tail` succeeds whatever `cmd` did, so a failing check reads as exit 0. The same trap applies to `| head`, `| grep`, `| jq`, and `| wc`. This has already produced a ✅ in a report for a check that was actually failing — twice in one run, on `format:check`.

Run the command bare and read its status, then pipe a *separate* invocation if you want readable output. Or capture `${PIPESTATUS[0]}` explicitly. Before writing any ✅, state the raw exit code you actually observed.

**If you did not observe an exit code, the mark is ⚠️ *unverified*, not ✅.** An unverified check is a Phase 5 line item, not a pass.

If all three pass: go to Phase 5.

If any fail: this counts as **attempt 1 of 3**.

### Iteration loop (attempts 2 and 3)

Parse each failure into discrete, file-scoped fix tasks. Dispatch a fresh round of parallel subagents — one per failure cluster — with the same prompt shape as Phase 3 plus the exact compiler/linter/test output for that failure. Then re-run typecheck + lint + test in parallel again.

**Hard limit: 3 attempts total.** After the 3rd failed attempt, stop iterating. Do not keep grinding. Carry the remaining failures into Phase 5 as items that still need the user.

If a failure looks like a *test asserting wrong behavior* (i.e. the test expectation is wrong, not the code), do not auto-fix it — classify it as needs-human-judgment and surface it. Never "fix" tests by changing the assertion to match broken code.

## Phase 5 — Final report

Output a single report with this structure:

```markdown
# /pre-pr-autonomous — Report

## Project commands used
<paste the PROJECT_COMMANDS block>

## Pre-pr skill summary
<one-paragraph summary of what pre-pr found>

## Auto-fixed (no action needed from you)
- `<file>:<line>` — <what changed> (subagent <id>)
- ...

## Verification
Every row names the command and the exit code you actually read. ⚠️ *unverified* is a valid row; a ✅ you did not observe is not.
- typecheck: ✅ pass (`<cmd>`, exit 0) | ❌ <n> errors after <k> attempts | ⚠️ unverified — <why>
- lint: ✅ pass (`<cmd>`, exit 0) | ❌ <n> errors after <k> attempts | ⚠️ unverified — <why>
- test: ✅ <p>/<t> passing (`<cmd>`, exit 0) | ❌ <f> failing after <k> attempts | ⚠️ unverified — <why>

New tests added this pass — each must state its falsification result:
- `<test file>` — <n> tests, all <n> fail against pre-fix code ✅ | <n> pass pre-fix ⚠️ pins nothing

## Claims I could not verify
Required section. If it is genuinely empty, write "None" — but check first: anything the sandbox blocks, any prod-only data, anything needing a device, and any conclusion that rests on a comment rather than executable code belongs here.
- <claim> — <why unverifiable here>

## Still needs you

### Fast path (skim — mechanical, no judgment)
- Hygiene fixes, formatting, lint-driven edits. These have a clean track record; a glance is enough.

### Floor path (read against the diff every time)
Anything Critical, any verification row, any claim about what a new test proves, and any product, compliance, or safety behavior. **Do not let this shrink as the flow earns trust elsewhere** — the thinnest reviews are where errors have survived.

#### Decisions / scope
- ...
#### Unresolved verification failures (after 3 attempts)
- <file>:<line> — <error message> — <why it's stuck>
#### Code review items (human judgment)
- Critical: ...
- Important: ...
- Minor: ...

## Suggested next moves
- 2–3 concrete next actions, ordered by impact.
```

### Label the provenance of every load-bearing claim

Split findings by what actually supports them:

- **Verified from executable code** — you read the statement that makes it true. Stale comments cannot affect these.
- **Taken from comments, docstrings, JSDoc, or schema doc strings** — prose that may not match the code.

Comments in real repos go stale, and this flow has been caught reasoning from an out-of-date docstring. **Never let prose be the only support for a Critical or Important finding.** When it is the only source available, mark the finding **requirements-dependent** and name who could confirm it.

## Hard rules

- **No git commits.** The user signs with a Yubikey. Report changed files; let them stage.
- **No PR creation** unless they explicitly ask after seeing the report.
- **A destructive suggestion requires a signal you can actually read.** Before proposing any `git reset`, `git checkout --`, branch deletion, or force-push, confirm the evidence is legible *in this environment*. Apply the **baseline test**: check the same signal against a known-good reference. If a commit you *know* is the user's shows the same status as the one you are flagging, your signal is measuring the sandbox, not the commit.
  - Specifically: **GPG `E` means "cannot check", not "unsigned"** — and the sandbox denies `~/.gnupg`, so `E` is the expected result for *every* commit here. Signature status is never grounds for a claim about provenance in this environment.
  - This rule exists because the flow once reported a nonexistent rogue commit and offered to `git reset --soft` what was actually the user's own signed work. Report the limitation instead of the conclusion.
- **Phase 0 is non-negotiable.** Wrong commands waste fix attempts and pollute the diff.
- **Parallelize everywhere it's safe** — Phase 3 subagents, Phase 4 verification commands. Sequential calls here are a bug.
- **Stop at 3 verification attempts.** Diminishing returns past that; the user's eyes are more valuable than another grind.
- **Bias toward surfacing.** If categorization is uncertain, put it in needs-human-judgment. Don't be heroic.
- **Your claims about your own work are the weakest part of the report.** Finding real defects is the part this flow does well. What it gets wrong is the epistemics of reporting: what was actually verified, what a new test actually proves, what a subagent actually confirmed, what a git signature actually means. Spend proportionate care there — a false ✅ is worse than a missed finding, because it buys unearned trust for everything else in the document.

$ARGUMENTS
