---
name: changelog-generation
description: Use when generating release notes or changelogs from PR merges, production deployments, or when the user asks for a summary of changes between branches or releases
---

# Changelog Generation

## Overview

Generate stakeholder-friendly changelogs from pull request merges. Analyzes individual PRs within a merge to produce non-technical release notes organized by impact category. Works for both monorepos (multi-project) and single-project repositories.

## When to Use

- User provides a PR link merging a development branch into production
- User asks for release notes or changelog for a deployment
- User asks to summarize changes between branches or tags

## Workflow

### 1. PR Analysis

1. **Receive PR link or branch range** from user
2. **Extract individual PRs** included in the merge using `gh pr list` or `gh api`
3. **Identify affected areas**: In monorepos, map changed file paths to projects. In single repos, identify affected modules/features.
4. **Analyze each PR**:
   - Extract title and description
   - Classify change type (feature, bug fix, enhancement, etc.)
   - Determine affected project(s) or module(s)
   - Summarize in non-technical terms considering broader codebase context

### 2. Content Guidelines

**Target audience**: Non-technical stakeholders

**Writing style**:
- Brief, high-level descriptions focusing on functionality, not implementation
- Bullet points for easy scanning
- No technical jargon or implementation details
- Focus on user impact and business value
- 1-2 lines maximum per item
- Present tense, active voice

**Exclude**:
- PR links
- Technical implementation details
- Code-specific terminology
- Developer-focused information

### 3. Categorization

Organize changes into these categories:

| Category | Include |
|----------|---------|
| **New Features** | New functionality, pages, forms, first-time implementations |
| **Bug Fixes** | Issue resolutions, error corrections, broken functionality fixes |
| **Enhanced User Experience** | UI/UX improvements, performance enhancements, accessibility |
| **[Dynamic 4th Category]** | Name based on remaining changes (e.g., "Infrastructure Updates", "Content Updates") |

### 4. Formatting

#### Single Project

```markdown
# Release Notes - [Date or Version]

## New Features
- [Brief description]

## Bug Fixes
- [Description of resolved issue]

## Enhanced User Experience
- [UI/UX improvement]

## [Dynamic Category Name]
- [Other improvements]
```

#### Monorepo (Multi-Project)

```markdown
# Release Notes - [Date or Version]

## [Project Name]

### New Features
- [Project-specific new functionality]

### Bug Fixes
- [Project-specific fixes]

## [Another Project]

### Enhanced User Experience
- [Project-specific improvements]

## System-Wide Changes

### [Dynamic Category Name]
- [Shared schema/infrastructure changes]
```

**Monorepo detection**: If the repo has a `turbo.json`, workspace config in `package.json`, or multiple distinct project directories, use multi-project format. Group changes by project, with a "System-Wide Changes" section for shared code.

## Quality Checklist

Before finalizing:
- [ ] All descriptions are non-technical and stakeholder-friendly
- [ ] Items properly categorized (by project in monorepos)
- [ ] No PR links included
- [ ] Bullet points are concise and scannable
- [ ] Dynamic 4th category has an appropriate name
- [ ] Content focuses on user/business impact
- [ ] Cross-project dependencies noted (monorepos)
