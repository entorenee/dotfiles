---
name: feature-plan
description: Use when a feature is about to be built and the work will span more than one sitting or more than one commit — turns it into phased commits with explicit MANUAL REVIEW CHECKPOINT gates between them (one commit per phase, not per task) and a paired risk-ordered QA checklist. A design doc is the ideal input but not a precondition.
---

# Feature Implementation Plan

## Overview

Produce two paired documents from an approved design doc:

1. **Implementation plan** — `$ARTIFACTS/plans/YYYY-MM-DD-<slug>-plan.md` (dev artifact; the artifact root is defined in the global CLAUDE.md under "Dev Artifact Storage"). Phased structure with explicit checkpoints between phases.
2. **QA checklist** — `$ARTIFACTS/plans/YYYY-MM-DD-<slug>-qa.md`. Risk-ordered manual test matrix.

This skill writes the plan + QA only. It does **not** write the design doc — `feature-design-doc` does that. For the full ticket-to-plan flow, use `feature-spec`.

## When to Use

- A design doc exists and is approved (user said "proceed to plan", "write the plan", "let's plan this out")
- User has an existing design doc and asks for an implementation plan
- Mid-flight: design doc was revised and the plan needs regeneration

## When NOT to Use

- No design doc exists yet — invoke `feature-design-doc` first
- The work is small enough that a plan adds ceremony (small bug fix, one-file change)

## Required Inputs

1. **Path to the design doc.** Ask if not obvious. The plan references it as the source of truth.
2. **Project commands** — discover via `package.json` / `pyproject.toml` / equivalent before writing. Pass exact commands (`pnpm test:ci`, not "run the tests") through to the plan.

## Commit Cadence Rule

**ONE COMMIT PER PHASE, not per task.** A medium feature should land in 3–5 commits. If you're writing a plan with 8+ commits, you're over-fragmenting — consolidate.

**Why:** The user signs commits with a Yubikey GPG key (physical touch required). Per-task tiny commits create a frustrating click-stream. Phase-sized commits group related work into reviewable units.

**Phase sizing heuristic:** a phase = a "vertical slice" that a reviewer would want to look at as one commit. ~2–5 files changed. Examples:

- "New hook + its tests" — one phase
- "New component skeleton + lifecycle effects" — one phase
- "Wiring into parent + safety effect + integration test" — one phase

**Anti-example to avoid:** a plan that assigns one commit per task. A real one ran to 11 commits for a single feature, which turns review into a click-stream and buries the vertical slices. Three phases and three commits, each an independently reviewable slice, is the shape to aim for.

## Plan Template

````markdown
# <Feature Title> Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** One-sentence goal.

**Architecture:** One-paragraph architecture summary. Lifted from the design doc.

**Tech Stack:** Bulleted list of relevant libraries/frameworks with versions where they matter.

**Source design doc:** `<path>` — read it before starting; it is the authoritative spec.

---

## Context for the Implementer

### Problem

One paragraph stating the current pain.

### Current State (if architectural — provider tree, data flow, etc.)

ASCII diagram or table.

### Target State

ASCII diagram or table.

### Key Files

| File | Role |
|---|---|
| `path/a` | What this file does for the feature |
| `path/b` | What this file does for the feature |

### Constraints

- One bullet per constraint
- Include project-specific gotchas (peer dep conflicts, API limitations, etc.)
- **Git:** Do not run `git add`, `git commit`, or any staging/committing commands. Report changed files and wait for the developer to review and commit.

---

## Phase 1: <Phase Title>

One-paragraph "what this phase delivers" framing.

### Task 1.1: <Task Title>

**Files:**
- Modify/Create: `path`

**Step 1: <Action>**

<Detail. Code snippets where helpful. Test-first encouraged but not enforced per-task; the phase as a whole should have tests.>

**Step 2: Run typecheck**

```bash
<exact command discovered from package.json>
```

Expected: No new errors.

### Task 1.2: <Task Title>

<As above>

### -- MANUAL REVIEW CHECKPOINT 1 --

**Files changed in this phase:** `<comma-separated list>`

**Suggested commit message:**
```
<message>
```

**What to test:**
1. <Test 1>
2. <Test 2>

**What could go wrong:**
- <Risk 1 and how to recover>
- <Risk 2 and how to recover>

**STOP here. Wait for the user to commit and confirm before starting Phase 2.**

---

## Phase 2: <Phase Title>

<as above>

### -- MANUAL REVIEW CHECKPOINT 2 --

<as above>

---

## Summary of Changes

| File | Change |
|---|---|
| `path` | Description |

## What This Does NOT Change

(Out-of-scope confirmation — lifted from the design doc.)
````

## QA Template

The QA doc lives separately so it can be checked off independently during testing.

````markdown
# <Feature Title> — Manual QA Checklist

**Branch:** `<branch>`
**Design doc:** `<design doc path>`
**Plan:** `<plan path>`
**Ticket:** <link>

The only honest test of <user-facing feature> is a real <something> with a real <something>.

## Pre-flight setup

- [ ] <Build / deploy step>
- [ ] <Test account ready>
- [ ] <Capture tool ready>

## Highest-risk checks (do these first)

These have hedges built into the design doc; if they fail, the fix is specified.

### A. <Risk name>

<Why this is risky>

- [ ] <Repro step>
- [ ] **Pass** = <expected behavior>
- [ ] **Fail** = <failure mode>

If fail: <fix path from design doc>.

## Happy path

- [ ] <Step 1>
- [ ] <Step 2>

## Exit paths

(If feature has multiple exit conditions, e.g. multi-state UI)

- [ ] **<Exit 1>** — <repro> → <expected>
- [ ] **<Exit 2>** — <repro> → <expected>

## Regression spot-checks

- [ ] <Adjacent feature not affected>

## Screenshots for the PR

- [ ] **Before, <platform>** — <what to capture>
- [ ] **After, <platform>** — <what to capture>

## QA findings (fill in after running this)

> Format per finding:
> - **Platform / device:** ...
> - **Step:** which checklist item
> - **What happened:** ...
> - **Fix decision:** fix-now / follow-up / wontfix
> - **Followup ticket:** link if applicable

(empty until QA runs)

## Decision after QA

- [ ] **Ship as-is** — all checks pass, ready for PR
- [ ] **Fix-now small** — minor issues to resolve in this PR
- [ ] **Fix-now structural** — high-risk check failed, code change needed
- [ ] **Punt** — known issues documented as follow-ups, PR ships with them called out
````

## Hard Stops

After writing the plan + QA:

1. **Print both absolute file paths.**
2. **Get explicit sign-off on the commit chunks before execution.** Each phase = one commit-sized chunk = one review unit. List each phase (files touched, what's reviewed at its checkpoint), then ask: *"These are the N commits I'll build. I stop after each for you to review and sign it. Confirm or adjust the boundaries before I start."* Negotiate granularity here: too many stops = over-fragmented (see the Commit Cadence Rule); too few = the user can't review in reasonable units. Settle it now so execution never has to guess where to stop.
3. **Resolve every stop/continue question now, never at execution time.** If you are unsure whether something is a review boundary, that is a planning question — surface it in step 2. Do not carry the ambiguity into execution and quietly resolve it as "keep going."
4. Do NOT auto-invoke `superpowers:executing-plans`. Wait for the user to say "execute" or similar.

## Common Mistakes

- **Per-task commits instead of per-phase.** If you find yourself writing 8+ `### -- MANUAL REVIEW CHECKPOINT --` markers, you have too many phases. Consolidate.
- **Phase ordering that scatters work across files.** A phase touching 6 files for a single conceptual change is worse than two phases touching 3 each.
- **Missing the "What to test" / "What could go wrong" at each checkpoint.** Without these, the checkpoint is a commit boundary, not a gate.
- **QA doc with happy path first.** Risk-order. The doc earns its keep when something breaks; happy-path-first buries the leverage.
- **Treating the QA doc as test cases for QE.** It's a checklist for the engineer (the user) to walk through on real devices, plus a deviation log. Findings stay in the doc.

## What a correct one looks like

- **Phased plan:** three phases, three commits, an explicit `-- MANUAL REVIEW CHECKPOINT --` between each, and every phase a vertical slice of ~2–5 files.
- **QA doc:** risk-ordered rather than happy-path-first, fix paths inline next to each check, decision matrix at the end.

Do not cite a specific plan file here. Paths into a work repository go stale and this repository is public.
