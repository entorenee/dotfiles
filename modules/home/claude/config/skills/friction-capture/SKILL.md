---
name: friction-capture
description: Use the moment something costs time in a way that will recur — an instruction repeated because an earlier correction did not take, an assumption that was wrong and expensive, a command blocked by a rule nobody had written down, a workaround discovered the hard way, a check that reported success while doing nothing. Writes one dated entry recording what it cost and what changed in response. Not for a bug in product code (use investigate), and not for session-level preferences or memory upkeep (use /reflect).
---

# Friction Capture

## Overview

One entry, written while the friction is fresh. Reconstructing friction later is
how the log's own worst error happened: an entry claiming seven corrections where
three were supported, plus a causal claim the cited quote contradicted when read
in full.

The log exists because `skill-reviewer` cannot see this class of cost. Its three
arms — corrections, interruptions, review-time gaps — all require someone to have
caught something. Friction that was absorbed rather than caught produces no
signal and reads as a clean run.

## When to Use

Fires on the *situation*, not on wanting a log entry:

- A correction had to be given twice. Watch the situation, not a keyword: "still"
  hits 41 of 815 typed turns (5%) and marks a question as often as a correction
- An assumption turned out wrong after work was built on it
- A command was refused, and the reason was a rule not written anywhere
- A workaround was found by trial rather than by reading
- A check passed vacuously — empty input, wrong flag, unobserved exit code
- A tool or document was read in full only to be discounted

## When NOT to Use

- A bug in product code → `investigate`
- Session-level preferences, memory upkeep → `/reflect`
- Something already covered by an existing entry → update that entry instead
- Smooth work. **Do not manufacture entries.** A session with no friction gets
  none.

## Hard rules

**Findings attach to documents and code, never to a person's judgment.** Write
*"`default.nix:308` claimed X"*, never *"the reviewer was wrong to…"*. The log
has already violated this once: an entry asserted, in a document intended for the
user's CTO, that a review call of theirs had been mistaken — with no evidence, and
the cited quote showed the opposite. The subject was a person's professional
judgment, the audience was their management, and the cost of being wrong was not a
retracted finding but a misrepresentation.

**Quote in full or do not cite.** A quotation trimmed to the clause that supports
the claim is the mechanism of the failure above.

**Mark unverified claims unverified.** Counts are re-derived, never relayed. Exit
codes are observed, never inferred. A false pass is more damaging than a missed
finding because it buys unearned trust for everything else in the entry.

## Step 1 — preflight

```bash
ROOT="${MY_CLAUDE_FRICTION_ROOT:?unset — run 'make rebuild', then start a new session}"
```

If `$ROOT` is not a git repository, stop and hand over the clone command rather
than writing anywhere else:

```
git clone git@github.com:entorenee/claude-friction.git "$MY_CLAUDE_FRICTION_ROOT"
```

```bash
mkdir -p "$ROOT/entries"
```

**Do not pull, and do not run git here at all.** `git-sync` fetches and
fast-forwards this repo on its own every 300s and on every write, so the clone is
already current for numbering. A manual pull duplicates the daemon, needs a
Yubikey touch, and fails outright inside the sandbox with a message naming access
rights rather than the `~/.ssh` read-deny that actually causes it.

The residue is a numbering race no pull would close anyway: an entry written on
another machine within the last sync interval is not visible here yet. If a number
collides, say so — it is cheap to renumber and the daemon merges either way.

**A collision will not announce itself, so step 3 checks for one after writing.** The
two machines produce differently-slugged filenames, so there is nothing for git to
conflict on: the rebase at `git-sync:428` succeeds and both entries land. Since the
F-number is a citation key, the cost is not the duplicate file but every later
reference to that number becoming ambiguous. `friction-briefing` re-checks the whole
set at review time for the collision this local check cannot see.

## Step 2 — check for an existing entry

```bash
grep -rl "<the-friction-in-two-words>" "$ROOT/entries/" 2>/dev/null
```

If an entry covers the same *class* of friction, update it. A recurrence is
stronger evidence than a second entry, and two entries for one class split the
count that makes it visible. **When correcting an entry, keep the correction
visible rather than overwriting** — the error is usually the more useful record.

## Step 3 — write the entry

Number from the highest existing entry:

```bash
ls "$ROOT/entries/" | sed -n 's/^F\([0-9]*\)-.*/\1/p' | sort -n | tail -1
```

Write `$ROOT/entries/F<n+1>-YYYY-MM-DD-<slug>.md`:

```markdown
# F<n> — <one line naming the friction, not the fix>

<What happened and what it cost. Two to five sentences. Name the observable
symptom, since that is what a future reader meets first.>

**Evidence:** <file:line, commit, transcript date, or command output. If a claim
is not verified, write `unverified:` in front of it.>
**Adaptation:** <what changed, or is proposed to change, in response.>
**Status:** open | designed | in-progress | resolved | wont-fix
**Class:** open | graduated | n-a
**Status-detail:** <prose — dates, PR links, retained corrections. Free-form.>
```

`Status` is this instance; `Class` is the lesson. Keep both enums bare — `--aging`
greps them — and put every word of prose in `Status-detail:`, which runs to EOF.

- `graduated` — became a test, lint, hook, or encoded convention. Candidate for
  deletion: something else now catches the drift the entry was holding.
- `open` — still documentary. This is the drain `--aging` reports.
- `n-a` — resolved by removing the thing; no lesson left to encode.

`Status: resolved` with `Class: open` is the normal shape, not a contradiction —
21 of 22 entries, none ever `graduated`. An entry is not finished when it stops
hurting.

Then confirm the number you just used is unique — the daemon may have fast-forwarded
another machine's entry in between your `ls` above and your write:

```bash
ls "$ROOT/entries/" | sed -n 's/^F\([0-9]*\)-.*/\1/p' | sort -n | uniq -d
```

Any output names a duplicated F-number. Renumber the entry you just wrote to the next
free number and say so in the hand-back. Do not run git to resolve it.

Print the absolute path.

## Step 4 — hand back

**Write the file and stop. Do not run git here at all** — `services.git-sync` commits
and pushes on its own, unsigned, within a few minutes. The log is a notepad; a
per-entry commit gate would gate *when* an entry lands, not whether it is fair, and
fairness is checked at review time by `friction-briefing`'s drill-down.

So the hand-back is one line: the absolute path, and that it will sync itself.

If the entry has *not* appeared on the remote after several minutes, the daemon is the
thing to inspect — `launchctl print gui/$UID/org.nix-community.home.git-sync-claude-friction`
on macOS, `systemctl --user status git-sync-claude-friction` on Linux. Report what it
says; do not commit by hand to work around it.

## Quick reference

| Step | Action |
|---|---|
| 1 | Resolve `$MY_CLAUDE_FRICTION_ROOT`; hand over `git clone` if absent; **no git, no pull** |
| 2 | Grep `entries/` for the same class — update rather than duplicate |
| 3 | Write `F<n>-YYYY-MM-DD-<slug>.md`; print the absolute path |
| 4 | Print the path and stop. **Run no git** — `git-sync` commits and pushes it unsigned within minutes |
