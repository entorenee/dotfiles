---
description: Beads trial only — move a beads-arm branch's plan into bd before the first edit, so every beads branch starts the same way. Retire at the trial decision (2026-12-16).
argument-hint: [plan path — optional if the branch has exactly one plan]
---

# /beads-kickoff

Start a beads-arm branch from its plan. Trial scaffolding: it defines how the beads arm begins,
so it runs the same steps on every beads branch and nothing else.

## 1. Confirm the arm — stop if it is not beads

Resolve the repo (`basename -s .git` of `git remote get-url origin`) and the branch
(`git symbolic-ref --short HEAD`), then find this branch's row in
`$MY_AGENT_ARTIFACTS_ROOT/dotfiles/beads-trial/arms.tsv`.

- Row says `beads`: continue.
- Anything else — `control`, no row, detached HEAD: **stop** and say which. Running this on a
  control branch contaminates the arm the trial compares against. Never add or change a row
  here; arms are set at `wt switch --create`.

## 2. Find the plan

Use `$ARGUMENTS` if given. Otherwise look in `$ARTIFACTS/plans/` (resolved per the global
`CLAUDE.md`) for the plan that names this branch or its ticket ID. One match: use it. None or
several: list what you found and ask — do not guess.

## 3. Check for existing beads state

`bd list --status=open` and search for the plan path or ticket ID. If an epic for this plan
already exists, report it and stop: this is a resume, so read it with `bd show` instead.

## 4. Create the issues — before any product edit

- One epic: the plan's title, the plan path and ticket ID in `-d`.
- One child per phase (`--parent=<epic>`), titled from the phase heading, with the phase's
  commit boundary and QA items in `-d`.
- `bd dep add` so each phase depends on the one before it.

## 5. Hand back

Print the epic ID, the phase issue IDs in order, and `bd ready`. Then state the working rules
for the rest of the branch:

- The plan file is the spec only: no ticked checkboxes, no status block, no progress ledger.
- Progress, decisions and deviations go in `bd update`; finished phases get `bd close`.
- Phase boundaries are still commit stops; name the issue ID when handing back.

Stop there. Do not start the first phase.
