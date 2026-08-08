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
Mechanical or unambiguous fixes where the correct answer is determined by the code, the project conventions in `PROJECT_COMMANDS`, or the diff itself. Examples:
- Stray `console.*`, `debugger`, leftover `it.only` / `describe.only`
- Unused imports, unused variables, dead code paths
- Lint errors with autofixable rules (let the linter do it)
- Type errors with a single obvious fix (missing import, wrong arg name, nullable narrowing)
- Replacing a banned API with the documented replacement (`logger.error` → `logError`)
- Adding missing unit tests to an *existing* test file for a *pure* function whose behavior is fully specified by the diff
- Formatting / prettier drift
- Typos in identifiers/strings that have a single likely correct spelling
- Adding obvious null checks where the code clearly assumes non-null but TS flags it

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

Use `subagent_type: general-purpose` unless the finding clearly matches a specialized agent. Pass `description` as a short label so it's identifiable in the dispatch list.

Wait for all subagents to return. Collect their reports.

## Phase 4 — Verify, iterate up to 3 times

Once subagents have returned, run the verification commands **in parallel** (separate Bash tool calls in a single message), using the exact scripts from `PROJECT_COMMANDS`:

- typecheck
- lint (the non-mutating variant — `lint:ci` if it exists, else plain `lint`)
- test (`test:ci` if it exists, else plain `test`)

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
- typecheck: ✅ pass | ❌ <n> errors after <k> attempts
- lint: ✅ pass | ❌ <n> errors after <k> attempts
- test: ✅ <p>/<t> passing | ❌ <f> failing after <k> attempts

## Still needs you
### Decisions / scope
- ...
### Unresolved verification failures (after 3 attempts)
- <file>:<line> — <error message> — <why it's stuck>
### Code review items (human judgment)
- Critical: ...
- Important: ...
- Minor: ...

## Suggested next moves
- 2–3 concrete next actions, ordered by impact.
```

## Hard rules

- **No git commits.** The user signs with a Yubikey. Report changed files; let them stage.
- **No PR creation** unless they explicitly ask after seeing the report.
- **Phase 0 is non-negotiable.** Wrong commands waste fix attempts and pollute the diff.
- **Parallelize everywhere it's safe** — Phase 3 subagents, Phase 4 verification commands. Sequential calls here are a bug.
- **Stop at 3 verification attempts.** Diminishing returns past that; the user's eyes are more valuable than another grind.
- **Bias toward surfacing.** If categorization is uncertain, put it in needs-human-judgment. Don't be heroic.

$ARGUMENTS
