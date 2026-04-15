# Dependency Upgrades - Detailed Reference

## Pre-Upgrade Analysis

### Dependency Assessment

Before starting any upgrade work:

- **Identify outdated packages**: `npm outdated`
- **Categorize by risk level**:
  - **Low Risk**: Dev dependencies, utility libraries with minimal API surface
  - **Medium Risk**: UI libraries, build tools, testing frameworks
  - **High Risk**: Core frameworks (React, Next.js), database ORMs, authentication
  - **Critical Risk**: Packages with known breaking changes or complex migrations
- **Check interdependencies**: Identify packages that must be updated together
- **Verify peer dependency requirements**: Check compatibility before attempting updates

### Baseline Establishment

**CRITICAL**: Establish a clean baseline before any updates:

1. **Pin all versions** - Remove `^` and `~` prefixes from package.json
2. **Verify zero errors** - The baseline MUST have:
   - ZERO TypeScript errors (`npm run tsc`)
   - ZERO ESLint errors (`npm run lint`)
   - ALL tests passing (`npm run test`)
   - Successful production build (`npm run build`)
3. **Commit the clean baseline** - This is your rollback point

## Phase-Based Execution Strategy

### Recommended Phase Order

1. **Infrastructure Setup** - Pin versions, establish clean baseline
2. **Low-Risk Updates** - Utility libraries and dev dependencies
3. **Development Tools** - Testing frameworks, linters, build tools
4. **Core Language** - TypeScript and related tooling
5. **Core Framework** - React, Next.js, Angular, Vue (one at a time)
6. **Data Layer** - Database ORMs, API clients
7. **UI Libraries** - Component libraries, styling frameworks
8. **External Services** - Authentication, analytics, third-party integrations
9. **Build Tools** - Bundlers, transpilers (if not updated earlier)

### Critical Rules

- **Minimize major version updates per phase**:
  - Ideal: Update one major package at a time
  - Exception: When packages are tightly coupled and MUST be updated together
  - Always prefer the smallest working set of major updates
- **One major version jump at a time**: Never skip versions (e.g., v5->v6->v7, not v5->v7)
- **Complete validation between phases**: Don't proceed until current phase is stable
- **Maintain working state**: Each phase should end with a committable, working codebase

### Common Coupled Package Groups

Packages that MUST be updated together:

- **React Ecosystem**: React + React DOM + @types/react + @types/react-dom
- **MUI Suite**: @mui/material + @mui/icons-material + @mui/x-* packages
- **Prisma**: @prisma/client + prisma CLI + @prisma/instrumentation
- **TypeScript Tooling**: TypeScript + @typescript-eslint/* packages
- **tRPC Stack**: @trpc/server + @trpc/client + @trpc/react-query + @trpc/next

**Decision Framework**:
1. Can the packages work with different major versions? -> Update separately
2. Do the packages share types or runtime dependencies? -> Update together
3. Does the documentation explicitly state they must match? -> Update together
4. When uncertain, attempt separate updates in a test branch first

## Validation Gates

### Zero Tolerance Policy

The following MUST be maintained at every phase:

- **TypeScript**: ZERO compilation errors
- **Linting**: ZERO ESLint warnings or errors
- **Tests**: ALL tests must pass
- **Build**: Production build MUST succeed
- **Baseline parity**: If the main branch is clean, your branch must be equally clean

### Responsibility Matrix

**AI Assistant Responsibilities (Automated Only):**

- Execute dependency updates via npm commands
- Run lightweight validation checks (tsc, lint, test)
- Maintain memory file with current progress and status
- Report results and STOP for approval
- Remind engineer to run build command at each checkpoint
- Research migration guides and breaking changes
- Report failures and wait for engineer direction - Never initiate rollbacks

**Engineer Responsibilities (Manual Only):**

- **Run production build** (`npm run build`) - CRITICAL
- Manual dev server testing
- Critical user path verification
- Performance validation
- Git commits after successful validation
- Approval to proceed to next phase
- **All rollback decisions** - AI must never rollback without explicit approval

**CRITICAL**: AI assistants must NEVER perform git operations (add, commit, push) or rollback procedures without explicit engineer approval.

## Migration Research Protocol

Before ANY major version update:

1. **Find Official Documentation**: Migration guides, CHANGELOG.md, GitHub release notes
2. **Identify Breaking Changes**: Removed/deprecated APIs, config changes, new peer deps, behavioral changes
3. **Check for Migration Tools**: Codemods, migration CLIs, ESLint migration plugins
4. **Assess Compatibility**: Verify dependent packages support the new version, check peer alignment

## Anti-Patterns

1. **Never delete package-lock.json** - Use `npm ci` for clean installs
2. **Never update unrelated major packages simultaneously** - Update one ecosystem at a time
3. **Never proceed with a broken state** - Fix before continuing; broken states compound
4. **Never skip the build validation** - Dev server success != build success
5. **Never ignore peer dependency warnings** - Research compatibility before forcing
6. **Never rollback without engineer approval** - Engineers may have alternative solutions

## Recovery & Rollback Procedures

**AI assistants must NEVER initiate rollback procedures automatically.**

### If Update Fails:

1. Stop immediately - don't compound the problem
2. Document the failure with error messages
3. Wait for engineer decision (fix, debug, or rollback)

### Engineer-Approved Rollback Process:

1. `git reset --hard HEAD~1` (engineer executes)
2. `npm ci` to restore from lock file
3. Run full validation suite
4. Root cause analysis before retry

### If Functionality Breaks:

1. Isolate and report the broken component/feature
2. Research solutions in breaking changes documentation
3. Present options: targeted fix, workaround, or rollback
4. Wait for engineer direction

## Memory File Management

For upgrades spanning multiple sessions, create a progress tracking file.

### When to Create

- Multi-phase dependency upgrade
- Major framework version upgrades
- Upgrades expected to span multiple sessions or days

### Naming Convention

`{project-name}-{upgrade-type}-memory.md` in `.claude/` directory

### Template

```markdown
# {Project Name} {Upgrade Type} Progress

## Current Status: {Current Phase} {Status}

**Branch**: `{branch-name}`
**Overall Progress**: {X}/{Total} phases completed ({percentage}%)

## Completed Phases

### Phase {X}: {Phase Name} (COMPLETED - {Date})

- **Key Updates**:
  - **Package**: {old version} -> {new version}

#### Issues Resolved

**Issue**: {Brief description}
**Root Cause**: {Technical explanation}
**Solution**: {What was implemented}

#### Validation Results

- TypeScript: {status}
- ESLint: {status}
- Tests: {status}
- Build: {status}

#### Lessons Learned

1. {Lesson with technical details}

## Remaining Phases

### Phase {X}: {Phase Name} (PENDING)

**Target Packages**:
- {Package}: {current version} -> {target version}

## Next Actions

1. {Immediate next step}
2. {Blockers to resolve}
```

### Update Protocol

**Mandatory updates:**
1. **End of each phase**: Status, validation results, issues, solutions, lessons learned
2. **After issue resolution**: Root cause, solution, prevention strategies
3. **Before engineer handoff**: Current state, next actions, blockers

**Status indicators**: COMPLETED, PENDING, BLOCKED, IN PROGRESS

## Communication Protocol

### Status Reporting Format

After each phase, report:

- Validation results (pass/fail for tsc, lint, test)
- Packages updated with version numbers
- Issues encountered and resolutions
- Next phase plan
- **REMINDER: Engineer must run `npm run build` before proceeding**

### Handoff Points

1. After automated validation - AI reports, engineer takes over
2. After manual validation - Engineer approves or requests fixes
3. Before next phase - Explicit approval required
4. On any failure - Full stop, wait for engineer direction
5. Before any rollback - Engineer must explicitly approve

## Common Issues Reference

### Peer Dependency Resolution

**Issue**: Package A requires Package B v2, but Package C requires Package B v3

**Solutions** (order of preference):
1. Align versions (upgrade/downgrade to compatible versions)
2. Check for newer versions with aligned dependencies
3. Use npm `overrides` as last resort (document the reason)
4. Consider alternative packages

### Build-Only Errors

**Issue**: Code works in dev but fails to build

**Common Causes**: TypeScript strict mode differences, dead code elimination, import resolution differences, environment variable handling

**Prevention**: Always run `npm run build` as part of validation

### npm ci Failures

**Issue**: `npm ci` fails without `--legacy-peer-deps`

**Prevention**: Resolve peer dependencies properly before committing. Never commit a state that requires `--legacy-peer-deps`.

## Quick Reference Commands

```bash
# Analysis
npm outdated                    # Show outdated packages
npm ls <package>                # Show dependency tree

# AI Validation Suite
npm run tsc                     # TypeScript check
npm run lint                    # ESLint check
npm run test                    # Test suite

# Engineer Validation (REQUIRED)
npm run build                   # Production build - MUST RUN
npm run dev                     # Dev server check

# Installation
npm ci                          # Clean install from lock file
npm install <package>@version   # Install specific version
```

## Engineer Validation Checklist

### After Each Phase:

- [ ] All automated checks pass (tsc, lint, test)
- [ ] Production build completes successfully (`npm run build`)
- [ ] Development server starts without errors
- [ ] Critical user paths tested (auth, core features, CRUD, APIs)
- [ ] No new console errors or warnings
- [ ] Memory file updated with complete phase status
- [ ] Git commit created with descriptive message

### Before Proceeding:

- [ ] Current phase fully validated
- [ ] No outstanding issues or workarounds
- [ ] Dependencies for next phase researched
- [ ] Rollback point clearly marked
