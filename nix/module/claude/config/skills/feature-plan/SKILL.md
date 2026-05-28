---
name: feature-plan
description: Use after a feature design doc is approved and an implementation plan is needed. Outputs a phased plan with explicit MANUAL REVIEW CHECKPOINT gates between phases (one commit per phase, not per task) and a paired risk-ordered QA checklist.
---

# Feature Implementation Plan

## Overview

Produce two paired documents from an approved design doc:

1. **Implementation plan** — `<project>/docs/plans/YYYY-MM-DD-<slug>-plan.md`. Phased structure with explicit checkpoints between phases.
2. **QA checklist** — `<project>/docs/plans/YYYY-MM-DD-<slug>-qa.md`. Risk-ordered manual test matrix.

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

**Anti-example to avoid:** the screenshare landscape plan at `fwapp2proto/docs/plans/2026-05-20-stream-screenshare-landscape-plan.md` has 11 per-task commits. Do NOT mirror that cadence. The session-suspense gate plan at `2026-04-20-session-suspense-gate.md` (3 phases, 3 commits) is the correct shape.

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

1. **Print both file paths.**
2. **Confirm the phase count and rough commit cadence** with the user before any execution begins.
3. Do NOT auto-invoke `superpowers:executing-plans`. Wait for the user to say "execute" or similar.

## Common Mistakes

- **Per-task commits instead of per-phase.** If you find yourself writing 8+ `### -- MANUAL REVIEW CHECKPOINT --` markers, you have too many phases. Consolidate.
- **Phase ordering that scatters work across files.** A phase touching 6 files for a single conceptual change is worse than two phases touching 3 each.
- **Missing the "What to test" / "What could go wrong" at each checkpoint.** Without these, the checkpoint is a commit boundary, not a gate.
- **QA doc with happy path first.** Risk-order. The doc earns its keep when something breaks; happy-path-first buries the leverage.
- **Treating the QA doc as test cases for QE.** It's a checklist for the engineer (the user) to walk through on real devices, plus a deviation log. Findings stay in the doc.

## Reference Examples

- **Phased plan (correct shape):** `fwapp2proto/docs/plans/2026-04-20-session-suspense-gate.md` — 3 phases, 3 commits, explicit `-- MANUAL REVIEW CHECKPOINT --` gates.
- **QA doc (correct shape):** `fwapp2proto/docs/plans/2026-05-20-stream-screenshare-landscape-qa.md` — risk-ordered, fix paths inline, decision matrix at end.
