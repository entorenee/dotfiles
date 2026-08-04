---
name: pr-review
description: Use when reviewing a GitHub pull request or a diff with multiple specialized review agents and you want every finding verified against the actual code before it is reported. Triggers on "review this PR", "kick off a PR review", pre-merge review requests.
---

# PR Review (grounded)

## Overview

Runs the `pr-review-toolkit:review-pr` plugin as the base engine, then adds a mandatory **code-grounding gate** and a fixed output/behavior contract. Core principle: **subagent findings are leads, not conclusions — nothing reaches the summary until it is tied to a real line of code.**

**REQUIRED BASE:** Use `pr-review-toolkit:review-pr` to determine applicable aspects and dispatch the specialized agents (code, tests, errors, types, comments). This skill layers on top of it — it does not replace it. If that plugin is unavailable, dispatch the equivalent review agents directly, then still apply the gate and contract below.

## Workflow

1. **Fetch the PR/diff.** `gh pr view <n>` for metadata, `gh pr diff <n>` for the change. Save the diff to a temp file so agents can read the PR's actual changes (not the working tree).
2. **Run the base.** Invoke `pr-review-toolkit:review-pr`. Dispatch the applicable agents **in parallel** against the saved diff. Tell each agent explicitly: review the diff, and read repo files only for context on unchanged helpers.
3. **Ground every finding in code (gate — BEFORE aggregating).** See below. Do not summarize a finding you have not personally verified.
4. **Aggregate** using the output contract below.

## The code-grounding gate

Agents overstate severity, misremember how a helper behaves, and assert root causes without opening the file. Verify each finding yourself:

- **Changed files → verify against the diff hunk.** Quote the exact `+`/`-` line. If the working tree is not on the PR branch (normal when reviewing someone else's PR), the working-tree copy does NOT reflect the PR — use `gh pr diff`.
- **Claims resting on unchanged code → read that file directly.** Logging/error-tracking wiring, a helper's return shape, a schema/type, framework validation behavior (e.g. does the event framework validate at emit?), an enum's allowed values. Unchanged helpers match the base branch, so reading them on the current checkout is valid. Never trust an agent's characterization of code it only described.
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
- Default to producing the review as a markdown artifact/file when the review is substantial, so it can be iterated on. Write it to `docs/local/reviews/YYYY-MM-DD-<slug>-review.md` (repo-root-relative, git-ignored dev artifact — never `git add`/`commit` it).

## Common mistakes

| Mistake | Fix |
|---|---|
| Relaying an agent's "Critical" verbatim | Ground it in a quoted line first, or downgrade/drop |
| Reviewing working-tree files for a PR on another branch | Review `gh pr diff`; read only unchanged helpers from the checkout |
| Reporting a loose-boundary suggestion as a live bug | Check whether any current caller can trigger it; label defensive if not |
| Multiple per-category tables | One table, one severity column, sorted descending |
