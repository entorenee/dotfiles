---
name: pre-pr
description: Use before opening a pull request — runs code-hygiene cleanup, verification, and code review, auto-fixes every finding a subagent can safely resolve, verifies until green, then reports only what still needs the engineer.
argument-hint: [optional scope reference — Asana task, GH issue, or freeform]
disable-model-invocation: true
---

# Pre-PR

An autonomous pre-PR pass. Fix everything that can be fixed without the user's
judgment, then surface only the residue. Speed matters — parallelize aggressively.

This skill is user-invoked only. Do not offer to run it because a branch looks
finished; it edits files and dispatches subagents, and the decision to start it
is the engineer's.

## When NOT to Use

- Mid-development cleanup only — use `code-hygiene` standalone
- Quick verification only — run typecheck/lint/test directly

## Phase 0 — Project command discovery (FIRST, before anything else)

Every later phase runs real commands against this repo, and so do the fix
subagents. They must use the project's actual scripts, not generic guesses.

1. **Read `package.json`** at the repo root. Capture the exact `scripts` keys for:
   - typecheck (commonly `typecheck`, `tsc`, `type-check`, sometimes only via `turbo`)
   - lint (prefer `lint:ci` if present — it is non-mutating)
   - test (prefer `test:ci` if present)
   - build (commonly `build`, `build:ci`)
   - format (commonly `format`, `prettier`)
2. **Detect the package manager** from the lockfile: `pnpm-lock.yaml` → pnpm,
   `yarn.lock` → yarn, `bun.lockb` → bun, `package-lock.json` → npm. Never assume.
3. **Detect the monorepo orchestrator**: `turbo.json` → turbo, `nx.json` → nx,
   `lerna.json` → lerna, `workspaces` field → workspaces. With turbo, prefer
   `<pm> turbo <task> --filter='...[<merge-base>]'` for affected-only runs.
4. **Read the nearest `CLAUDE.md`** (repo root first, then any closer to the
   changed files). Capture documented conventions: logging helpers (e.g.
   `logError` vs `logger.error`), error wrappers, import paths, test patterns,
   banned APIs.
5. **Record the values in a `PROJECT_COMMANDS` block.** Every later phase reads
   from it, and it is passed verbatim into every subagent prompt.

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

If `package.json` does not exist (non-JS repo), record that and adapt: read the
equivalent manifest (`Cargo.toml`, `pyproject.toml`, `go.mod`) and the project's
Makefile/justfile for canonical commands.

**Do not skip Phase 0.** Everything downstream depends on it. Proceeding without
it means running wrong commands and wasting a fix attempt.

## Phase 1 — Resolve inputs

Resolve **once**; every later phase shares these values.

### Base branch

```bash
for b in develop main master; do
  if git rev-parse --verify --quiet "refs/heads/$b" >/dev/null; then BASE_BRANCH=$b; break; fi
done
MERGE_BASE=$(git merge-base "$BASE_BRANCH" HEAD)
```

### Scope reference

Accept in priority order:

1. **Asana task ID/URL** — pull the description via Asana MCP (`get_task`)
2. **GitHub issue number** — pull via `gh issue view <number>`
3. **Freeform text** — the engineer provides scope inline
4. **None** — ask. If still none, continue without scope and note that scope
   compliance was skipped.

### Artifacts root and branch register

```bash
ARTIFACTS="${MY_CLAUDE_ARTIFACTS_ROOT:?run 'make rebuild', then start a new session}/$(basename -s .git \
  "$(git remote get-url origin 2>/dev/null || git rev-parse --show-toplevel)")"
REGISTER="$ARTIFACTS/registers/$(git rev-parse --abbrev-ref HEAD | tr '/' '-').md"
cat "$REGISTER" 2>/dev/null
```

`domain-register` specifies that a register is read on resume and **diffed at PR
time**, and this phase is the only place that diff can happen — a row is checked
against the code *as built*, which does not exist until the review pass has read the
diff. Without it a register only ever accumulates rows, which is the failure it was
built to prevent.

No register is the normal case: note it once and carry on. If one exists, hold every
row until Phase 6 and resolve each against the diff there.

### Empty diff guard

If `git diff --name-only $MERGE_BASE...HEAD` returns nothing, report "No changes
found between HEAD and $BASE_BRANCH — nothing to review." and stop. Run nothing.

## Phase 2 — Review pass

### Step 2a — Code hygiene

Execute the full `code-hygiene` skill workflow:

- Auto-fix artifacts (console.*, debugger, commented-out code)
- Auto-fix convention violations whose documented rule names its one replacement
- Auto-add unit tests to existing suites
- Collect findings (scope compliance, ambiguous convention violations, TODOs, test suggestions, observations)

Pass the Phase 0 `PROJECT_COMMANDS` block into it — the convention swaps are
verified with the project's own typecheck, and hygiene has no discovery of its own.

Capture the full output — auto-fixed items and findings both feed Phase 3.

### Step 2b — Verification

Run after hygiene, since hygiene edits files. **Use the commands from
`PROJECT_COMMANDS`** — do not substitute defaults. If Phase 0 found `test:ci`,
run `test:ci`; running `test` instead is the Phase 0 failure this skill warns
about, one phase later.

Record pass/fail and error counts. If auto-added tests from Step 2a fail,
attribute those separately from pre-existing failures.

#### Exit-code discipline

This governs every verification run in this skill, here and in Phase 5.

**A pipeline reports the status of its *last* command.** `cmd | tail -15` gives
you `tail`'s status, and `tail` succeeds whatever `cmd` did — so a failing check
reads as exit 0. Same trap with `| head`, `| grep`, `| jq`, `| wc`. This has
already put a ✅ in a report for a check that was failing, twice in one run.

Run the command bare and read its status, then pipe a *separate* invocation for
readable output, or capture `${PIPESTATUS[0]}`. State the raw exit code you
observed before writing any ✅.

**An unobserved result is ⚠️ unverified, not a pass.** Never infer that a check
passed because nothing looked wrong. An unverified check is a report line item.

### Step 2c — Dispatch the code reviewer

Dispatch the `superpowers:code-reviewer` agent using the existing
`code-reviewer.md` template.

**Template values:**

- `{WHAT_WAS_IMPLEMENTED}` — from the scope reference
- `{PLAN_OR_REQUIREMENTS}` — same, plus any Step 2b verification failures
- `{BASE_SHA}` — the computed `MERGE_BASE`
- `{HEAD_SHA}` — current `HEAD`
- `{DESCRIPTION}` — one-line summary of the branch changes

The reviewer operates on the branch **after** hygiene auto-fixes, so it will not
flag artifacts that were already cleaned up.

**Append these focus areas to the reviewer prompt.** The default checklist reads
files in isolation; these require reasoning across files and across time, and are
exactly what single-file review misses:

- **Cross-component render ordering.** When an effect closes/dismisses an overlay,
  modal, or branch in response to a prop or hook return that changed elsewhere,
  trace what the render tree looks like *the frame after* the trigger flips but
  *before* the effect runs. Look for a gap where neither branch's guard holds
  (blank/placeholder render) or where a child fully remounts (expensive re-init,
  re-fetch, re-attach). Prefer `useLayoutEffect` or a combined guard over
  `useEffect` for synchronous close.
- **Sync vs. async / timing primitives.** Flag `setTimeout`/`requestAnimationFrame`
  used to wait for a platform transition (orientation change, layout settle,
  navigation animation). These are guesses against device-dependent durations. The
  correct fix is an event/callback (`addOrientationChangeListener`, `onLayout`,
  transition-end). When the diff offers a fixed-delay timer, treat it as a
  known-fragile fallback needing human sign-off — do not bless it as equivalent.
- **Author hedge comments are unsolved problems, not design intent.** If a changed
  region carries a comment hedging about fragility/timing/races ("if QA reveals
  flicker…", "on slow devices…", "might need to bump this"), surface it verbatim
  as an Important issue. Do not adopt the comment's workaround as the fix.
- **Comments are not evidence.** Label each load-bearing claim as *verified from
  executable code* or *taken from a comment/docstring/JSDoc*. Docstrings in this
  repo have been demonstrated out of date. Never let prose be the sole support for
  a Critical or Important finding — when it is the only source, mark the finding
  **requirements-dependent** and name who could confirm it.
- **A behavior that looks like a bug may be intended.** Before reporting two
  surfaces as inconsistent, ask whether they answer *different questions*. Product
  and compliance rules are frequently absent from the repo entirely, so a confident
  "divergence" or "should fail open" finding is exactly the kind domain knowledge
  overturns. State the assumption the finding rests on so it can be checked in one
  sentence.

## Phase 3 — Categorize findings

Split every "needs review" and "issues" item from Phase 2 into two buckets.

### auto-fixable (a subagent can resolve without user input)

Mechanical or unambiguous fixes where the correct answer is determined by the
code, by `PROJECT_COMMANDS`, or by the diff itself: stray artifacts and dead code,
lint-autofixable rules, formatting drift, type errors with a single obvious fix, a
banned API swapped for its documented replacement, and unit tests added to an
*existing* suite for a *pure* function the diff fully specifies. `code-hygiene`
owns the artifact classes — do not re-enumerate them here.

### needs-human-judgment (surface; do NOT dispatch)

Anything requiring product, design, or architectural judgment, or where the "fix"
could plausibly be more than one thing:

- Scope deviations ("file X modified but not in ticket")
- Ambiguous TODOs ("// TODO: revisit — keep or remove?")
- New test files for behavior not fully specified by the diff
- Behavior changes flagged by the reviewer (correctness debates)
- Anything Critical or Important unless it is a pure mechanical fix
- Dependency upgrades or new dependencies
- Schema / migration changes
- Anything where you would need to ask "which of these did you mean"

**Rule of thumb:** if a competent engineer would resolve it in under two minutes
without asking anyone, it is auto-fixable. Otherwise it is human-judgment. When in
doubt, classify as human-judgment — the cost of surfacing too much is small; the
cost of an autonomous wrong fix is large.

## Phase 4 — Dispatch parallel fix subagents

One Task subagent per auto-fixable finding. **All subagents in a single message**
so they run concurrently. Use `subagent_type: general-purpose` unless the finding
clearly matches a specialized agent, and pass a short `description` label.

Each prompt MUST include, verbatim:

1. The `PROJECT_COMMANDS` block from Phase 0
2. The specific finding (file path, line number, exact issue text)
3. **Scope clamp**: "Modify only the file(s) named in this finding. Do not touch
   unrelated code. Do not run typecheck/lint/test — the orchestrator does that
   after all subagents return."
4. **Verification clamp**: "After editing, re-read the file to confirm the change
   is correct. Report back: file(s) modified, what changed, any obstacles."
5. **Convention enforcement**: "Use exactly the commands and conventions in
   PROJECT_COMMANDS. If you would have run `npm` or `console.error` or
   `logger.error`, stop and use the documented replacement."
6. **Falsification clamp** (any finding whose fix adds or edits a test): "A new
   test is not done until it has failed. Run it against the pre-fix
   implementation — `git stash` your change, or point the import at
   `git show HEAD:<file>` — and confirm it **fails** for the right reason. Report
   the falsification result next to the pass. If it passes both before and after,
   it pins nothing; say so instead of reporting it as coverage."
7. **Evidence clamp**: "Quote the exact line that justifies your fix. If you cite
   a schema default, a field being unused, or a lifecycle guarantee, you must have
   read it in the file — not inferred it from a name or a nearby model."

### Subagent output is unverified input, not results

Before any of it reaches the report:

- **Re-derive every count yourself.** Test totals, error counts, files-changed —
  read them from the command output you ran in Phase 5, never from a subagent's
  summary. A relayed count has been wrong in practice.
- **Re-ground every factual claim** a subagent used to justify its fix, by opening
  the file and quoting the line. Claims of the form "field X has default Y",
  "variable Z is unused", or "callback W always fires" have all been fabricated. If
  the claim fails but the fix is still right, keep the fix and **correct the stated
  reason** — a right fix with a wrong rationale gets deleted by the next reader who
  checks it.

## Phase 5 — Verify, iterate up to 3 times

Run the verification commands **in parallel** (separate Bash calls in one
message), using the exact scripts from `PROJECT_COMMANDS`: typecheck, lint
(non-mutating variant), test. The Step 2b exit-code discipline applies unchanged.

If all three pass, go to Phase 6. If any fail, this is **attempt 1 of 3**.

### Iteration loop (attempts 2 and 3)

Parse each failure into discrete, file-scoped fix tasks. Dispatch a fresh round of
parallel subagents — one per failure cluster — with the same prompt shape as Phase
4 plus the exact compiler/linter/test output for that failure. Then re-run all
three checks in parallel again.

**Hard limit: 3 attempts total.** After the 3rd failed attempt, stop. Carry the
remaining failures into Phase 6 as items that still need the user.

If a failure looks like a *test asserting wrong behavior* (the expectation is
wrong, not the code), do not auto-fix it — classify it as needs-human-judgment.
Never "fix" tests by changing the assertion to match broken code.

## Phase 6 — Final report

**Write the report to a file, always — this is not optional and not conditional
on length.** A report that exists only in the conversation forces the engineer to
scroll back through a long autonomous run to review anything, which is exactly the
cost this skill is supposed to remove. Chat gets a short summary; the file is the
artifact.

```bash
mkdir -p "$ARTIFACTS/reviews"   # $ARTIFACTS resolved in Phase 1
# → $ARTIFACTS/reviews/YYYY-MM-DD-<branch-or-pr>-pre-pr.md
```

Print the absolute path in the chat summary. Then keep the summary to what the
engineer must act on now — the decisions needing judgment and the next moves —
and leave the full finding list, evidence, and verification table in the file.

The file's contents are the template below.

```markdown
# /pre-pr — Report

## Project commands used
<paste the PROJECT_COMMANDS block>

## Code hygiene
### Auto-fixed
- Removed `console.log` at `src/lib/api/client.ts:47`
- Added 2 unit tests to `src/lib/hooks/__tests__/useAuth.test.ts`

## Auto-fixed by subagents (no action needed)
- `<file>:<line>` — <what changed> (subagent <id>)

## Verification
Every row names the command and the exit code you actually read. ⚠️ unverified is
a valid row; a ✅ you did not observe is not.
- typecheck: ✅ pass (`<cmd>`, exit 0) | ❌ <n> errors after <k> attempts | ⚠️ unverified — <why>
- lint: ✅ pass (`<cmd>`, exit 0) | ❌ <n> errors after <k> attempts | ⚠️ unverified — <why>
- test: ✅ <p>/<t> passing (`<cmd>`, exit 0) | ❌ <f> failing after <k> attempts | ⚠️ unverified — <why>

New tests added this pass — each must state its falsification result:
- `<test file>` — <n> tests, all <n> fail against pre-fix code ✅ | <n> pass pre-fix ⚠️ pins nothing

## Claims I could not verify
Required section. If genuinely empty, write "None" — but check first: anything the
sandbox blocks, any prod-only data, anything needing a device, and any conclusion
resting on a comment rather than executable code belongs here.
- <claim> — <why unverifiable here>

## Domain register
Required section. Write "No register for this branch" if none exists — do not omit it,
or a missing diff is indistinguishable from a missing register. When one exists, report
every row against the code as built, using `domain-register`'s four outcomes:
- `blocked` row still blocked — **the PR is not ready.** Say so rather than shipping
  around it, and repeat it in the chat summary; this is the one register finding that
  changes whether the branch should merge at all.
- `assumed` row the implementation depends on — **goes in the PR description.** The
  reviewer is the last person who can catch it.
- `verified` row whose citation no longer resolves — re-verify. A moved line is not a
  wrong rule, but an unresolvable citation is not evidence.
- a rule the work relied on that no row covers — add it, and note that the register
  missed it. That is the register's own failure mode and it is worth recording.

## Still needs you

### Fast path (skim — mechanical, no judgment)
- Hygiene fixes, formatting, lint-driven edits. These have a clean track record.

### Floor path (read against the diff every time)
Anything Critical, any verification row, any claim about what a new test proves,
and any product, compliance, or safety behavior. **Do not let this shrink as the
flow earns trust elsewhere** — the thinnest reviews are where errors have survived.

#### Decisions / scope
#### Unresolved verification failures (after 3 attempts)
- <file>:<line> — <error message> — <why it is stuck>
#### Code review items (human judgment)
- Critical / Important / Minor

## Suggested next moves
- 2–3 concrete next actions, ordered by impact.
```

## Hard rules

- **Comments are not evidence.** Label each load-bearing claim as *verified from
  executable code* (you read the statement that makes it true) or *taken from a
  comment/docstring/JSDoc* (prose that may be stale). Docstrings in these repos
  have been demonstrated out of date, and this flow has been caught reasoning from
  one. Never let prose be the sole support for a Critical or Important finding —
  when it is the only source, mark the finding **requirements-dependent** and name
  who could confirm it.
- **Counts are re-derived, never relayed** — from command output, not a summary.
- **Exit codes come from the command, not from a pipe.** An unobserved result is
  ⚠️ unverified, never a pass.
- **No git commits.** The user signs with a Yubikey. Report changed files; let
  them stage.
- **No PR creation** unless they explicitly ask after seeing the report.
- **A destructive suggestion requires a signal you can actually read.** Before
  proposing any `git reset`, `git checkout --`, branch deletion, or force-push,
  confirm the evidence is legible *in this environment*. Apply the **baseline
  test**: check the same signal against a known-good reference. If a commit you
  *know* is the user's shows the same status as the one you are flagging, your
  signal is measuring the sandbox, not the commit.
  - Specifically: **GPG `E` means "cannot check", not "unsigned"** — and the
    sandbox denies `~/.gnupg`, so `E` is the expected result for *every* commit
    here. Signature status is never grounds for a provenance claim in this
    environment.
  - This rule exists because the flow once reported a nonexistent rogue commit and
    offered to `git reset --soft` what was actually the user's own signed work.
    Report the limitation instead of the conclusion.
- **Phase 0 is non-negotiable.** Wrong commands waste fix attempts and pollute the
  diff.
- **Parallelize everywhere it is safe** — Phase 4 subagents, Phase 5 verification.
  Sequential calls there are a bug.
- **Bias toward surfacing.** If categorization is uncertain, it is
  human-judgment. Do not be heroic.
- **Your claims about your own work are the weakest part of the report.** Finding
  real defects is what this flow does well. What it gets wrong is the epistemics of
  reporting: what was actually verified, what a new test actually proves, what a
  subagent actually confirmed, what a git signature actually means. Spend
  proportionate care there — a false ✅ is worse than a missed finding, because it
  buys unearned trust for everything else in the document.

$ARGUMENTS
