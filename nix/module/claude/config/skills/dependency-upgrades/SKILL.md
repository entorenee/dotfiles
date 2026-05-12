---
name: dependency-upgrades
description: Use when upgrading, updating, or bumping npm dependencies, especially major version upgrades spanning multiple packages or sessions. Also use when user asks to update outdated packages, resolve peer dependency conflicts, or plan a dependency migration.
---

# Dependency Upgrades

## Overview

Systematic, phased approach to npm dependency upgrades with validation gates between each phase. Core principle: **one major version bump at a time, fully validated before proceeding.**

## When to Use

- Upgrading outdated npm dependencies (especially major versions)
- Planning a multi-package upgrade strategy
- Resolving peer dependency conflicts
- Any `npm outdated` showing multiple major bumps

**Not for:** Single patch/minor bumps, adding new dependencies, or non-npm ecosystems.

## Workflow

```dot
digraph upgrade_flow {
    rankdir=TB;
    node [shape=box];

    assess [label="1. Assess\nnpm outdated\nCategorize risk"];
    baseline [label="2. Baseline\nPin versions\nVerify zero errors\nCommit clean state"];
    research [label="3. Research\nMigration guides\nBreaking changes\nPeer deps"];
    phase [label="4. Execute Phase\nSmallest working set\nof major updates"];
    validate [label="5. Validate\ntsc + lint + test\n(AI runs these)"];
    engineer [label="6. Engineer Gate\nnpm run build\nManual testing\n(MUST NOT skip)"];
    done [label="All phases done?" shape=diamond];
    memory [label="7. Update Memory\nVersions, issues,\nlessons learned"];
    complete [label="Complete"];

    assess -> baseline -> research -> phase -> validate;
    validate -> engineer [label="pass"];
    validate -> phase [label="fail\nfix first"];
    engineer -> done [label="approved"];
    engineer -> phase [label="rejected\nfix issues"];
    done -> memory -> phase [label="no\nnext phase"];
    done -> complete [label="yes"];
    complete -> pr [label="engineer\nasks for PR"];
    pr [label="8. Create PR\nDraft mode ONLY\nWait for engineer\nto request this"];
}
```

## Quick Reference

| Rule | Detail |
|------|--------|
| **Phase order** | Dev tools -> TypeScript -> Core framework -> Data layer -> UI libs -> External services |
| **Coupled packages** | Update together: React+ReactDOM+types, Prisma client+CLI, MUI suite, tRPC stack, TS+eslint-typescript |
| **Version jumps** | One major at a time (v5->v6->v7, never v5->v7) |
| **Phase 1 completeness** | Bump every package to its latest within-current-major. Don't trust `npm outdated` alone — see below |
| **Validation** | Zero TS errors, zero lint errors, all tests pass, build succeeds - after EVERY phase |
| **Never do** | Delete package-lock.json, skip build step, proceed with broken state, rollback without approval |
| **AI boundary** | Run tsc/lint/test. NEVER run build, commit, push, or rollback without explicit engineer approval |
| **Commit scope** | Don't bump packages unprompted between explicit phases. Each commit/phase covers only what the engineer approved |
| **PR creation** | NEVER auto-create. Wait for engineer to ask. Always use `--draft` mode |

## Phase 1 Completeness: Latest Within-Major

`npm outdated` reports the absolute `latest` for each package. When `current == wanted`, it tells you nothing about whether a newer minor/patch exists *within your current major*. This is a frequent miss: a package pinned at `5.6.0` shows up as outdated against `7.8.0` (deferred major), but the `5.22.0` patch within v5 silently gets skipped.

**Always check latest-in-major for every package whose major is being deferred**, then include those bumps in Phase 1.

Quick check (substitute the major and package list):

```bash
# For each package whose major you're keeping, find the highest version in that major
for pkg in "@prisma/client@5" "next@15" "stripe@15"; do
  v=$(npm view "$pkg" version 2>/dev/null | tail -1)
  echo "$pkg => $v"
done
```

Or with a `package.json` driving the list:

```bash
node -e "
const p = require('./package.json');
const deps = {...p.dependencies, ...p.devDependencies};
for (const [name, ver] of Object.entries(deps)) {
  const major = ver.replace(/^[\^~]/, '').split('.')[0];
  console.log(\`\${name}@\${major}\`);
}
" | xargs -I {} sh -c 'echo "{} => $(npm view "{}" version 2>/dev/null | tail -1)"'
```

Then diff that list against current pins to catch every available within-major bump. Bundle them all into Phase 1.

## Peer Dependency Conflicts

Resolution order of preference:
1. Align versions (upgrade/downgrade to compatible range)
2. Check for newer versions of conflicting packages
3. `overrides` in package.json (last resort, document why)
4. Consider alternative packages

## Migration Research (Before ANY Major Bump)

1. Read official migration guide and CHANGELOG
2. Identify removed/deprecated APIs and new peer deps
3. Check for codemods or migration CLI tools
4. Verify downstream packages support the new version

## Memory File for Multi-Session Upgrades

For upgrades spanning multiple sessions, create a progress file in `.claude/` tracking: current phase, completed phases with exact versions, validation results, issues/lessons, remaining phases, and next actions. See `detailed-guide.md` in this skill directory for the full template.

## Anti-Patterns

- Updating unrelated major packages simultaneously
- Skipping `npm run build` (dev success != build success)
- Deleting package-lock.json instead of using `npm ci`
- Ignoring peer dependency warnings
- Committing a state that requires `--legacy-peer-deps`

## Communication Protocol

After each phase, report: validation results, packages updated (old -> new), issues encountered, and next phase plan. Always remind engineer to run `npm run build` before approving.

## Pull Request Creation

**NEVER auto-create a PR.** Wait for the engineer to explicitly ask you to create one. When asked:

- Always create in **draft** mode (`--draft`)
- Use the PR template below

### PR Template

```markdown
## Summary

{1-2 sentence overview: what this PR covers and how it fits into the larger upgrade effort.}

### Phase 1: Minor & Patch Updates ({count} packages)

**Phase 1a — {description} ({count} packages):**
{comma-separated list of package names}

**Phase 1b — {description} ({count} packages):**
{comma-separated list with notable version jumps called out, e.g. "@aws-sdk/client-s3 (3.629→3.1034)"}

### Phase 2: Major Version Bumps ({count} packages)

| Package | From | To | Risk | Blast Radius |
|---------|------|----|------|-------------|
| `{package}` | {old} | {new} | {Very Low/Low/Medium} | {N files — brief justification} |

### Code Changes (beyond package.json)

- **`{file path}`** — {what changed and why}

### Other

- {Deferred upgrades with reasons}
- {Removed unused packages with justification}
- {Notable peer dep resolutions}

## Test plan

- [x] `npm run tsc` — {result}
- [x] `npm run test` — {result}
- [x] `npm run build` — verified by engineer
- [ ] Verify dev server starts cleanly
- [ ] Smoke test critical paths (auth, navigation, data tables)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### Key Principles

- **Risk column**: Rate each major bump (Very Low / Low / Medium) based on blast radius and API surface change
- **Blast radius**: State file count and why it's safe (e.g., "1 file — dev dep for test data only", "0 files — CLI-only usage")
- **Deferred section**: Document what was intentionally skipped and why (peer dep blockers, resolution conflicts, risk too high for this batch)
- **Code changes section**: Only list changes beyond package.json/lock — import path fixes, API adaptations, test updates, snapshot refreshes

## Full Reference

See `detailed-guide.md` in this skill directory for complete phase-by-phase instructions, memory file templates, responsibility matrix, recovery procedures, and common issues reference.
