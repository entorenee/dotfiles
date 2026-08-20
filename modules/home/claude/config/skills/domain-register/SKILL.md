---
name: domain-register
description: Shared substrate defining the domain-assumption register — the three-state format for product rules a repository does not contain, where a register instance persists, how it is read on resume and diffed at PR time, and the graduation drain that empties it. Invoked BY investigate and feature-plan; NOT used directly and NOT a target for direct user requests.
---

# Domain Register

## Overview

The largest class of correction on this codebase is not a code error. The code
reasoning is usually right; the **business rule is nowhere in the source**, so it
cannot be read and gets assumed instead. Recorded instances: field agents can supply
jobs outside the industry, so counting them is a false positive; every class had
already moved to async, so a missing email was only ever orientation's; a column that
looked like the obvious join key was "not the right case" and a hardcoded map was
wanted.

None of that is discoverable from the repository. A register is where such a rule is
written down the first time it is needed, so the second session does not rediscover it
and the reviewer can see what the work rests on.

**This file defines the format and the rules. It does not do anything on its own.**
Consumers invoke it, then follow it.

## When NOT to Use

- **Directly.** This is substrate. If a user asks for "a register," they want the
  entry point that produces one — `investigate` for a bug, `feature-plan` for a
  feature.
- For a fact that *is* in the repository. A rule readable from the source is not a
  register row; cite the source and move on.
- For session-level preferences or harness drift → `/reflect`.
- For friction encountered while working → `friction-capture`.

## Where a register instance lives

```bash
ARTIFACTS="${MY_CLAUDE_ARTIFACTS_ROOT:?run 'make rebuild', then start a new session}/$(basename -s .git \
  "$(git remote get-url origin 2>/dev/null || git rev-parse --show-toplevel)")"
BRANCH="$(git rev-parse --abbrev-ref HEAD | tr '/' '-')"
REGISTER="$ARTIFACTS/registers/$BRANCH.md"
mkdir -p "$ARTIFACTS/registers"
```

**Its own file, keyed by branch — not a section of a design doc.** The register has to
exist when no design doc does; that is the whole reason the entry points no longer
require one. Nesting it inside a design doc would rebuild the dependency.

Keying on the branch and resolving `$ARTIFACTS` from the **remote name** means every
worktree of a repo resolves the same path, so a register written on a feature branch is
readable from a sibling worktree and survives `wt remove`. Sanitize `/` to `-`, matching
worktrunk.

**Print the absolute path whenever you write to it.** It is outside the editor tree, so
an unannounced register is an invisible one.

## The three states

One line per rule. The rule is stated as a **claim about intended behavior**, not as a
question and not as a task.

| State | Written as | Behavior |
|---|---|---|
| **verified** | `verified: <path:line>` — or `verified: <person>, <date>` when a human answered | Proceed. The citation is mandatory; `verified` with nothing after it is an `assumed` row wearing the wrong label. |
| **assumed** | `assumed` — optionally `assumed — <why this reading>` | Proceed, **and state it in the hand-back.** An assumption the reviewer never sees is indistinguishable from one nobody made. |
| **blocked** | `blocked: <who can answer>` | **Stop.** Do not proceed on this rule. |

```markdown
| Rule | State |
|---|---|
| A supplied job outside the industry still counts toward the placement total | `blocked: the product owner` |
| Orientation is the only class that still sends a synchronous email | `verified: mailers/orientation.rb:44` |
| The legacy reference column is unique per carrier, not globally | `verified: user, 2026-08-20` |
| Invoices are re-checked on edit, not only on create | `assumed — the create path is the only one with a hook, so this may be unintentional` |
```

### `blocked` is the state that does work

`verified` and `assumed` already existed, informally, in `investigate` step 5. The
problem with that pair is that **both proceed**. A load-bearing assumption and a
verified fact took the same path, so the only thing separating them was whether anyone
happened to read the hand-back.

`blocked` is the third state, and it stops the run. Use it when the rule is
load-bearing — a different answer changes what gets built — **and** no artifact in the
repository can settle it.

When you set a row to `blocked`, stop and post both halves:

```
BLOCKED — <the rule, as a question that has a yes/no or a value as its answer>
Who can answer: <a named person or a named role>
What changes on each answer: <the fork, concretely>
Everything else that can proceed without this: <list, or "nothing">
```

**Name a person or a role, never "the team" or "stakeholders."** An unaddressed
question is not a blocker, it is a note. And do the work that does not depend on the
answer before stopping — blocking the whole task on one row is a scope decision the
user did not make.

**Do not resolve a `blocked` row by picking the likelier reading and marking it
`assumed`.** That is the failure this state exists to prevent, and it is invisible
afterward.

## Read on resume, diff at PR time

A register that is only written is a scratchpad. Two obligations make it a register:

**On resume — read it before doing anything else.** Context does not survive
compaction or a session boundary, and per-feature domain truth has no other home. If a
register exists for this branch, read it first; if a row says `blocked`, that block is
still live until someone answered it, regardless of what the conversation remembers.

**At PR time — diff intent against outcome.** Walk every row and check it still holds
against the code as built:

| Found at PR time | Do |
|---|---|
| An `assumed` row that the implementation depends on | Surface it in the PR description. The reviewer is the last person who can catch it. |
| A `blocked` row still blocked | The PR is not ready. Say so rather than shipping around it. |
| A `verified` row whose citation no longer resolves | Re-verify. A moved line is not a wrong rule, but an unresolvable citation is not evidence. |
| A rule the work relied on that is in no row | Add it, and note that the register missed it — that is the register's own failure mode. |

## The graduation drain

**A confirmed rule that can be expressed as a test leaves the register and becomes
one.** Delete the row in the same change that adds the test, and name the test in the
commit.

This is the part every append-only document in this system lacks. A register that only
grows becomes a document that must be read in full to be discounted, which has failed
at the moment it is consulted. The register holds **only what cannot be tested yet**.

Not every row can graduate, and the ones that cannot are the register's real content: a
rule about intent that no assertion can capture ("this total is meant to include
supplied jobs"), or a rule still `blocked`. Do not manufacture a test to empty a row —
an assertion that restates the code proves nothing and now has to be maintained.

## For consuming skills

Invoke this, then:

1. Resolve `$REGISTER` as above. Read it if it exists.
2. Add a row for every product rule the work depends on that the repository does not
   contain. State the rule, not the question.
3. Any row that is `blocked` — stop on that row, per the format above. Do everything
   that does not depend on it first.
4. State every `assumed` row in the hand-back, not only in the file.
5. Graduate what you can, and delete those rows.

**The register is not a substitute for asking.** It records what was assumed so the
assumption is visible; it does not make assuming acceptable when someone could have
been asked cheaply.

## Quick reference

| Step | Action |
|---|---|
| Locate | `$ARTIFACTS/registers/<branch>.md`, `/` → `-`; print the path when written |
| States | `verified: <path:line>` proceeds · `assumed` proceeds **and is stated in the hand-back** · `blocked: <who>` **stops** |
| Blocked | Post the rule as an answerable question, a named person, the fork, and what can proceed without it |
| Resume | Read the register first; a `blocked` row is live until answered |
| PR time | Diff every row against the code as built; surface `assumed` rows in the PR description |
| Drain | A rule expressible as a test graduates out — delete the row, name the test |
