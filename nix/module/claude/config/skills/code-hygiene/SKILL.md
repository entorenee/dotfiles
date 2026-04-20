---
name: code-hygiene
description: Use when cleaning up a feature branch at any stage of development — removes dev artifacts, checks scope compliance against a ticket or description, identifies test gaps, and auto-adds unit tests to existing suites. Usable standalone or as part of the pre-pr orchestrator.
---

# Code Hygiene

## Overview

Branch cleanup and scope compliance tool. Removes development artifacts, verifies changes stay in scope, identifies test gaps, and auto-adds unit tests where patterns exist. Usable at any point during development — not just pre-PR.

## When to Use

- Before opening a PR
- Mid-development to clean up accumulated artifacts
- After a large implementation to verify scope compliance
- When invoked by the `pre-pr` orchestrator skill

## When NOT to Use

- On branches with no changes from the base (nothing to review)
- For deep code quality / architecture review (use `superpowers:requesting-code-review`)

## Input Resolution

### Base Branch

Auto-detect via merge base. Fallback order: `develop` → `main` → `master`.

```bash
# Detect base branch
BASE_BRANCH=$(git rev-parse --verify develop 2>/dev/null && echo develop || \
  git rev-parse --verify main 2>/dev/null && echo main || echo master)
MERGE_BASE=$(git merge-base $BASE_BRANCH HEAD)
```

### Scope Reference

Resolve in priority order. Use whichever the engineer provides:

1. **Asana task ID/URL** — Pull task name and description via Asana MCP (`get_task`)
2. **GitHub issue number** — Pull via `gh issue view <number>`
3. **Freeform text** — Engineer provides scope description inline
4. **None provided** — Ask the engineer. If still none, skip scope compliance (Phase 4) and note it in the report

## Workflow

```dot
digraph code_hygiene {
  rankdir=TB;
  "1. Setup" -> "2. Auto-fix artifacts";
  "2. Auto-fix artifacts" -> "3. Auto-add tests";
  "3. Auto-add tests" -> "4. Findings report";
  "4. Findings report" -> "Engineer reviews findings";
  "Engineer reviews findings" -> "Apply approved changes" [label="approves some"];
  "Engineer reviews findings" -> "Done" [label="no action needed"];
  "Apply approved changes" -> "Done";
}
```

### Phase 1 — Setup

Collect all data needed for subsequent phases:

```bash
# Changed files
git diff --name-only $MERGE_BASE...HEAD

# Full diff (for artifact detection)
git diff $MERGE_BASE...HEAD

# Diff of only added/modified lines (for precise artifact targeting)
git diff $MERGE_BASE...HEAD --diff-filter=AM
```

Parse the scope reference per the priority order above. If an Asana task ID is provided, fetch the task description. If a GH issue number, fetch the issue body.

**Empty diff guard:** If `git diff --name-only` returns nothing, report "No changes found between HEAD and $BASE_BRANCH — nothing to review." and stop.

### Phase 2 — Auto-fix Artifacts

Remove development artifacts **only from lines introduced in the branch diff**. Never modify pre-existing code.

**Auto-removed (no approval needed):**

| Artifact | Detection |
|----------|-----------|
| `console.log` / `console.warn` / `console.error` | Statement on a diff-added line |
| `debugger` | Statement on a diff-added line |
| Commented-out code blocks | Multi-line `//` or `/* */` blocks on diff-added lines that contain code structure (function calls, variable assignments, JSX) — not prose comments |

**Safety rules:**
- **Logger files:** Skip auto-removal for `console.*` inside files whose path contains `logger`, `logging`, or `debug` in the name
- **Diff-only:** Only target lines that appear as additions in the branch diff. Use the diff hunks to identify exact line ranges.
- **Commented-out code vs. real comments:** Only remove comments that contain code patterns (e.g., `// const x = ...`, `// return <Foo />`). Preserve explanatory prose comments, TODOs, and documentation comments.

After applying removals, record what was removed (file, line, content) for the report.

### Phase 3 — Auto-add Tests

Identify new exports that lack test coverage and add unit tests where an existing test suite can be extended.

**Step 1 — Find new exports:**
Scan the diff for newly exported functions, hooks, constants, and types in:
- Utility files (`lib/`, `utils/`, `helpers/`)
- Custom hooks (`hooks/`, files matching `use*.ts`)
- Pure functions and data transforms

**Step 2 — Check for existing test files:**
For each new export, look for a corresponding test file:
- `*.test.ts` / `*.test.tsx` sibling
- `__tests__/` directory with matching name

**Step 3 — Auto-add or suggest:**

| Condition | Action |
|-----------|--------|
| Test file exists | Add unit tests matching the file's existing patterns (imports, describe blocks, naming) |
| No test file exists | **Do not create** — surface as a suggestion in Phase 4 |
| Complex logic where expected behavior is ambiguous | **Do not auto-add** — surface as a suggestion in Phase 4 |

**Scope:** Unit tests only — utilities, hooks, pure functions. Never auto-add integration or E2E tests.

### Phase 4 — Findings Report

Present all findings that require engineer judgment. **Do not act on any of these without explicit approval.**

#### Report Structure

```markdown
## Code Hygiene Report

### Auto-fixed
- Removed `console.log` at `src/lib/api/client.ts:47`
- Removed `console.log` at `src/components/ProfileScreen.tsx:23`
- Removed commented-out code block at `src/utils/format.ts:15-22`
- Added 2 unit tests to `src/lib/hooks/__tests__/useAuth.test.ts`

### Needs Your Review

#### Scope
- `prisma/schema.prisma` was modified but not referenced in ticket scope — intentional?
- `src/components/unrelated/Footer.tsx` changed but ticket describes header work

#### TODO/FIXME Comments
- `src/components/FWButton.tsx:42` — `// TODO: add haptic feedback` — remove or keep?
- `src/lib/api/client.ts:89` — `// FIXME: retry logic` — remove or keep?

#### Test Suggestions
- **New test file needed:** `src/lib/utils/formatDate.ts` has no test file — consider creating `src/lib/utils/__tests__/formatDate.test.ts`
- **Integration test:** The new form submission flow touches validation, API call, and navigation — consider an integration test
- **Edge case:** `parseUserInput` doesn't handle empty string input — worth a test case

#### Other Observations
- `calculateTotal` in `src/utils/pricing.ts:30` duplicates logic from `src/lib/cart/totals.ts:12` — consider reusing
- The new `UserCard` component is 180 lines — consider extracting the avatar section
```

## Rules

- **Never auto-fix anything in Phase 4** — all findings require explicit engineer approval before action
- **Never touch pre-existing code** — only lines introduced in the branch diff
- **Never create new test files** — only extend existing test suites
- **Never auto-add integration or E2E tests** — suggest only
- **Skip logger files** for console.* removal (path contains `logger`, `logging`, or `debug`)
- **Report what you did** — every auto-fix and auto-added test must appear in the report with file:line references
