---
name: pr-review
description: Use when reviewing a GitHub pull request or a diff with multiple specialized review agents and you want every finding verified against the actual code before it is reported. Triggers on "review this PR", "kick off a PR review", pre-merge review requests — and equally on re-review requests once a PR has been reviewed before: "the PR has been updated", "there are new pushes", "review the changes against your previous concerns", "which of your findings are fixed".
---

# PR Review (grounded)

## Overview

Runs the `pr-review-toolkit:review-pr` plugin as the base engine, then adds a mandatory **code-grounding gate** and a fixed output/behavior contract. Core principle: **subagent findings are leads, not conclusions — nothing reaches the summary until it is tied to a real line of code.**

**REQUIRED BASE:** Use `pr-review-toolkit:review-pr` to determine applicable aspects and dispatch the specialized agents (code, tests, errors, types, comments). This skill layers on top of it — it does not replace it. If that plugin is unavailable, dispatch the equivalent review agents directly, then still apply the gate and contract below.

## Workflow

0. **Check for a prior review of this PR** in `$ARTIFACTS/reviews/` (the filename carries `pr<n>`). If one exists, take the re-review path below instead — the question is no longer "what is wrong with this PR."
1. **Fetch the PR/diff, and record the head SHA.** `gh pr view <n>` for metadata, `gh pr diff <n>` for the change. Save the diff to a temp file so agents can read the PR's actual changes (not the working tree). Record the SHA — it is what the next pass diffs from:

   ```bash
   HEAD_SHA=$(gh pr view <n> --json headRefOid -q .headRefOid)
   ```

2. **Run the base.** Invoke `pr-review-toolkit:review-pr`. Dispatch the applicable agents **in parallel** against the saved diff. Tell each agent explicitly: review the diff, and read repo files only for context on unchanged helpers.
3. **Ground every finding in code (gate — BEFORE aggregating).** See below. Do not summarize a finding you have not personally verified.
4. **Aggregate** using the output contract below, naming the SHA reviewed. If the head moved while the review was running, say so rather than silently reporting against a diff that has been superseded.
5. **Write the review to a file** at `$ARTIFACTS/reviews/YYYY-MM-DD-pr<n>-<slug>-review.md`, with `Reviewed at <HEAD_SHA>` in its header, and print the absolute path. Do this as part of the run, not on request — the file is what the second pass reads. A review that exists only in chat scrollback cannot be diffed against later, which forces the whole re-review to be driven by hand.

   **Put the re-review contract in the file's own header**, one line, immediately after the SHA:

   > *Re-reviews update this file in place — refresh the SHA, mark resolved items, append new findings. Never renumber, never start a new file.*

   A re-review is frequently requested in words that do not load this skill ("the PR has been updated"), and in that case the prior review file is the only instruction the run will see. The rule has to travel with the artifact, not only with the skill.

## Re-review — when a prior review file exists

The common case, and the one this workflow used to leave to the user: the review lands, the author pushes fixes, and what is wanted is **which flagged items are now resolved** — not another cold pass.

1. Read the prior file and its recorded SHA.
2. Isolate what moved between that SHA and the current head. Everything before it has already been reviewed.
3. **Report every prior finding** as one of:
   - **Fixed** — quote the line that resolves it. The grounding gate applies here too: an author saying it is fixed, or a commit message claiming it, is not evidence.
   - **Still present** — quote the line, unchanged.
   - **Superseded** — the code it described no longer exists in that form; say what replaced it.
4. Review the new commits for **new** findings, numbering them after the existing ones.
5. Update the file in place — refresh the SHA, mark resolved items, append new ones. **Never renumber, and never start a fresh file.** Item numbers are how the user refers to findings across sessions ("fix items 2 and 3"), so they have to survive the second pass.

## The code-grounding gate

Agents overstate severity, misremember how a helper behaves, and assert root causes without opening the file. Verify each finding yourself:

- **Changed files → verify against the diff hunk.** Quote the exact `+`/`-` line. If the working tree is not on the PR branch (normal when reviewing someone else's PR), the working-tree copy does NOT reflect the PR — use `gh pr diff`.
- **Claims resting on unchanged code → read that file directly.** Logging/error-tracking wiring, a helper's return shape, a schema/type, framework validation behavior (e.g. does the event framework validate at emit?), an enum's allowed values. Never trust an agent's characterization of code it only described.
- **Drop or mark what you can't ground.** Anything not tied to a specific line is dropped or explicitly labeled unverified/hypothesis.
- **Correct the agent — and your own relayed claims.** Fix severity to match what is literally present. Separate **live bugs** (a real caller can trigger today) from **defensive/hardening** suggestions (no current caller can, but the boundary is loose). If grounding shows the framing was wrong even after you wrote it up, restate it precisely.

## Output contract

- **One consolidated findings table**, columns `# | Severity | Item | Location | Detail`, **sorted by descending severity** (🔴 Blocker → 🟡 Worth fixing → 🟢 Minor). Consolidate for information density but leave enough detail to act on.
- Follow the table with a short **"Verified sound (no action)"** line naming what was checked and cleared.
- Note which findings are **code-verified** vs. which rest on **operational config / environment you cannot see from the repo** (deploy env vars, infra) — attribute those rather than asserting them.
- Never label a finding **Critical/Blocker** without a quoted line from the actual code.

## Behavior

- **Never post to GitHub** (comments, reviews, approvals). Surface everything in chat.
- **Surface decisions and forks as plain chat text**, not a modal picker.
