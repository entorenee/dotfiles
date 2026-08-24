---
name: investigate
description: Use when investigating bugs, test failures, or unexpected behavior — adds the local gates that upstream debugging skills do not have: a batched intake, the domain register, existing-test analysis, and a mandatory hand-back before any fix. Delegates the root-cause method to superpowers:systematic-debugging and the fix loop to superpowers:test-driven-development rather than restating either.
---

# Investigate

## Overview

**A wrapper, not a workflow.** The root-cause method and the fix loop live upstream and
are invoked, not restated. The global `CLAUDE.md` already carries the standing rules and
is loaded in every session. What is left — and all this file should ever hold — is the
handful of gates that exist because *these* sessions went wrong in specific ways.

## When to Use

- Bug report or ticket needs investigation
- Test failure needs diagnosis
- Unexpected runtime behavior

## When NOT to Use

- Greenfield feature work → `superpowers:brainstorming`, then `feature-plan`
- Refactoring with no known bug

## What this deliberately does not restate

Read this before adding anything. Every row is content that is already loaded or already
invoked, and re-stating it here has cost this file ~200 lines twice.

| Subject | Lives in | Not here because |
|---|---|---|
| Discovering the project's build/test/lint commands | `CLAUDE.md` § Project Command Discovery | It already names the `PROJECT_COMMANDS` block and the pass-verbatim-to-subagents rule |
| Reporting pass/fail per check before claiming done | `CLAUDE.md` § Verification | Same rule, loaded every session |
| Not expanding scope; deleting superseded logic | `CLAUDE.md` § Scope & Approach | Same |
| Evidence before a severity or root-cause claim | `CLAUDE.md` § Code Review & Diagnosis | Same |
| Artifact paths | `CLAUDE.md` § Dev Artifact Storage | Same |
| Root-cause methodology — hypothesis discipline, backward value tracing, per-boundary instrumentation, the architecture question after three failures | `superpowers:systematic-debugging` | Step 2 invokes it |
| The red-green fix loop | `superpowers:test-driven-development` | Step 7 invokes it |

## 1. Intake — one round of questions, not several

Fill every slot you can from what you were given. **Read linked sources first** — a named
ticket, issue, or doc, via the Asana MCP, `gh`, or WebFetch — before asking anything.

| Slot | Required? | If still missing after reading |
|---|---|---|
| **Symptom** | Yes | Blocker — stop and ask |
| Platform / component | No | Infer, and state the inference |
| Repro status / steps | No | Ask in this round |
| Hypothesis | No | Fine to omit; step 2 generates its own |

**Read the branch register now, and fold anything live into this same ask:**

```bash
ARTIFACTS="${MY_CLAUDE_ARTIFACTS_ROOT:?run 'make rebuild', then start a new session}/$(basename -s .git \
  "$(git remote get-url origin 2>/dev/null || git rev-parse --show-toplevel)")"
cat "$ARTIFACTS/registers/$(git rev-parse --abbrev-ref HEAD | tr '/' '-').md" 2>/dev/null
```

No register is the normal case and needs no comment. If one exists, a `blocked` row is
live until someone answered it — see `domain-register`. **Its question goes in this
message**, not three steps later: one ask to one person is the whole reason the register
is read at intake rather than at root cause.

Then **ask once.** Batch every gap into a single round. Do not ask serially, and do not
ask for anything you can reasonably infer.

## 2. Invoke `superpowers:systematic-debugging`

Unconditionally, before forming any theory of your own. Not "if the bug seems complex" —
that phrasing produced zero invocations across eighteen runs, because a judgment trigger
on Claude's own procedure is indistinguishable from skipping it.

It owns reproduce-consistently, read-the-error, check-recent-changes, single-hypothesis
discipline, tracing a bad value back to its origin, and instrumenting each boundary in a
multi-component system. Everything below is additive to it.

## 3. Two reproduction cases it does not cover

**Rule out your own environment before diagnosing the product.** Recorded runs have spent
real effort on the wrong worktree, a stale generated client, an unpublished CMS entry, and
a broken toolchain `expo-doctor` named immediately. Each produces a plausible false root
cause. Confirm the branch and worktree, confirm generated artifacts are current, and
confirm the failure reproduces somewhere other than this machine — or say plainly that it
has only been seen locally.

**For "it reverts on refresh" bugs, localize the layer first.** Did the value change in
the datastore, or only in the response, cache, or serialization? Inspect the actual request
payload against the response body: a request carrying only field A that comes back with
field B changed points away from the client and toward server-side validation, an ORM
layer, or a trigger.

## 4. Name the product rules the root cause assumes

**The largest correction class on this workflow is not a code error.** The code reasoning
is usually right; the failure is a business rule that is nowhere in the repository. Real
examples: field agents can supply jobs outside the industry, so counting them is a false
positive; every class had already moved to async, so the missing email was only ever
orientation's; a column that looked like the obvious join key was "not the right case" and
a hardcoded map was wanted.

None of that is discoverable from source. Record each as a register row — **invoke
`domain-register`** for the format and the graduation rule.

**Three states, and only two proceed.** `verified: <path:line>` and `assumed` both
continue, so alone they leave a load-bearing guess indistinguishable from a cited fact.
`blocked: <who can answer>` **stops.** Do everything that does not depend on the answer,
then stop and name both the question and the person. **Do not downgrade a `blocked` row by
picking the likelier reading** — that is the move the state exists to prevent, and it
leaves no trace.

A divergence between two surfaces may mean they answer different questions rather than
that one is broken. That is a register row, not a bug, until someone confirms which.

## 5. Check the existing tests before fixing

| Found | Meaning |
|---|---|
| Tests cover this path and **pass** | Red flag. Either the test mocks away the layer the bug lives in — in which case the test environment is untrustworthy and gets rewritten first — or your root cause is wrong. Go back to step 2. |
| Tests cover it and **fail** | Good. Proceed. |
| No coverage | Proceed test-first. |

**A passing test may encode the bug as expected behavior.** A test asserting the very
value the bug produces is evidence the bug is systemic, not evidence the code is correct.
Flipping that assertion is part of the fix — say so explicitly when you do.

## 6. HAND BACK — stop here, before fixing

**This is a real stop.** Root cause in hand with the fix looking obvious is exactly where
this workflow loses the human. Interruptions cluster on two messages — the one announcing
a confirmed root cause, and the one opening a long autonomous stretch — and they are the
same moment.

Post four things, then stop:

1. **Root cause**, one sentence: the mechanism, not the symptom.
2. **The fix you intend**, and at which layer.
3. **Assumptions it rests on** — every `assumed` register row, stated.
4. **Whether the fix stays inside the scope you confirmed.** If not, say so and ask; do
   not widen it on your own authority. Recorded corrections here: *"I don't want to change
   the contract without more engineering discussion"*, *"let's keep the out of scope items
   since I don't know for sure if they need to change."*

Skip only if the user said to run straight through. **Not because the fix is small** —
most of the interrupted runs looked small too.

## 7. Fix — invoke `superpowers:test-driven-development`

Red, green, then clean up only what you touched. No surrounding refactors, no unrelated
improvements, no speculative error handling.

## 8. Verify

Run the project's own typecheck, lint, and test commands per `CLAUDE.md` § Project Command
Discovery and § Verification. Two things that section does not say:

**Read the exit code you actually observed.** A pipeline reports its *last* command's
status, so `<test cmd> | tail -20` hands you `tail`'s zero whatever the tests did. Run it
bare, read the status, and pipe a second invocation for trimmed output. A check you did
not observe is **unverified** — a real result to report, and never a pass.

**Delegate the run when context is precious**, with `model: sonnet` — it is command
execution plus failure-excerpt extraction, no diagnostic judgment. Paste the
`PROJECT_COMMANDS` block in verbatim; a subagent inherits no discovery and will otherwise
guess.

**Cap the loop at 3 attempts, and count once.** `systematic-debugging` states the same
limit with a sharper escalation — after three, question whether the architecture is sound
rather than whether the hypothesis was. Use its escalation; do not count to three twice.

## 9. Blast radius

If the fix touches shared code, run the **unscoped** test command — the point is the code
you did not touch. In a monorepo prefer the orchestrator's affected-only form against the
merge base, since a shared utility's radius crosses package boundaries.

**Shared infrastructure needs a named human, not a green suite.** Schema files,
migrations, event contracts, and router wiring are owned by someone. Name who has to
agree and what they need to confirm, and say which parts of your evidence are grounded in
code you read versus inferred from structure.

Report which files changed. Do not stage or commit.

## Quick reference

| Step | Gate |
|---|---|
| 1 | Slots filled; register read; **one** batched ask including any `blocked` row |
| 2 | `superpowers:systematic-debugging` invoked — unconditionally, not on judgment |
| 3 | Own environment ruled out, or "local only" stated; layer localized for revert-on-refresh |
| 4 | Every product assumption a register row; a `blocked` row stopped the run |
| 5 | Existing tests checked; a passing test over buggy code investigated, not trusted |
| 6 | **Root cause, fix, assumptions, scope posted — and stopped** |
| 7 | `superpowers:test-driven-development` invoked; minimal, no scope creep |
| 8 | Exit codes observed not inferred; one 3-attempt cap |
| 9 | Unscoped suite if shared code; named human for infrastructure |
