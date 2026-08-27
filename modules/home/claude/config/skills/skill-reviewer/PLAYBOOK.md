# skill-reviewer — failure playbook

Companion to `SKILL.md`. That file says how the loop is *meant* to run; this one
says what happens when an input is missing, stale, reorganized, or corrupt — and
what the next operator should do about it.

Every row below was executed, not reasoned about. Measured 2026-08-27 against a
copied corpus; the live transcript archive was never modified.

## Why this file exists

This loop is the only unattended workflow in the system, and its output is not a
report — it is **edits to other skills' instruction text**. A wrong number here
does not produce a bad reading; it produces a bad rule that then shapes every
future session. So the interesting question is never "does it work" but "when it
is wrong, does it say so."

The answer, for four of seven modes, is no.

## Failure modes

Severity is about **silence**, not size. A loud wrong answer is a nuisance; a
quiet plausible one is the thing this playbook is for.

| # | Mode | Observed | Silent? |
|---|---|---|---|
| F1 | Ledger row with an off-convention date | `last_reviewed` retargets to an unrelated date on the same line | **yes** — exit 0, no stderr |
| F2 | Ledger headers reorganized (`##` → `###`) | zero rows parsed; output identical to *no ledger* | **yes** |
| F3 | Truncated transcript | aggregate deflates ~22%; session count unchanged | **yes** |
| F4 | Unreadable transcript | whole session vanishes from the denominator | partly — grep warns, exit code unchecked |
| F5 | Volume doubles | sub-linear; well inside budget | n/a — no failure |
| F6 | Alert missed on run day | no record the alert fired, failed, or was due | **yes** |
| F7 | Notifier blocks | script hangs with no timeout | no — but leaves no trace either |
| F8 | A second repo grows a ledger | one ledger is read, the other discarded | **yes** |

**F1, F2 and F8 are fixed** as of the ledger-arm change; their rows above record
what was observed before it, which is what makes the fix testable. The ledger now
lives at one canonical path above the repo layout, the date parse is anchored to
the token after the em dash, and `ledger_status` reports `absent` / `empty` /
`unparsed` / `split:<n>` / `parsed:<n>` so the three states that used to render
as an identical column of dashes are now distinguishable. `inventory.sh
--selftest` pins all three against fixtures. F3, F4, F6 and F7 remain open.

### F1 — a malformed date silently becomes a *different, plausible* date

The ledger parser scans a header line for the first date-shaped token. The live
row convention allows a second date in a parenthetical:

```
## <unit> — 2026-08-12 (row renamed 2026-08-17)
```

Reformat the first date and the scan falls through to the parenthetical. Tested:
a row whose review date was written `08/12/2026` reported `last_reviewed` as
**2026-08-17** — five days newer, wrong field, entirely plausible. A second row
in the same file dropped out silently.

This is the worst mode in the set. The direction is adverse: a *newer* date
suppresses the 45-day staleness arm, so the failure hides units that are overdue
rather than surfacing ones that are not.

- **Detection** — none today. Exit 0, empty stderr, well-formed JSON.
- **Alert** — none.
- **Fallback** — none; the sweep consumes the value as fact.
- **Catch before shipping** — only a human who remembers the real review date.

### F2 — a reorganized ledger is indistinguishable from an absent one

Rewriting headers to `###` yields `last_reviewed: null` for every unit — byte
-identical output to "this machine has no ledger" and to "the ledger is empty".
`inventory.sh`'s own footer already admits it conflates two of these states;
the test shows there is a third, and it is the dangerous one, because the ledger
*exists and is populated* while the sweep reports that it does not.

`/system-review` is instructed to say "this machine has no ledger" on a column of
dashes. Under F2 that instruction makes it state something false.

- **Detection / Alert / Fallback / Catch** — as F1: none, none, none, human memory.

### F3 — a truncated transcript quietly deflates the aggregate

Cutting one transcript to 55% of its length moved the mined totals:

| | gate turns | corrections | sessions |
|---|---|---|---|
| clean | 58 | 8 | 6 |
| truncated | 45 | 6 | **6** |

A 22% drop in the denominator that Step 4 normalizes against, with the session
count unchanged — so nothing in the output shape looks different.

**The mechanism is worse than a swallowed error: there is no error.** The miner
slurps each file as a raw string, and a truncated JSONL is a perfectly valid
string. `jq` exits 0 and prints nothing to stderr. Removing the `2>/dev/null`
from the documented pipeline would not surface this; the loss is invisible by
construction, not by suppression.

Splicing a NUL and invalid UTF-8 into the middle of a record changed nothing —
that shape is tolerated. Truncation is the one that bites.

- **Detection** — none today.
- **Alert** — none.
- **Fallback** — none.
- **Catch before shipping** — `signals.sh --verify` re-derives the *structural*
  aggregate independently and would diverge. It is not run over this arm, and
  SKILL.md only requires it before quoting a structural number.

### F4 — an unreadable transcript removes a session

A file the process cannot read drops out of the pre-filter entirely: sessions
6 → 5, gate turns 58 → 41. `grep` does warn on stderr and exits 2, but the
documented pipeline redirects stdout to the file list and never checks the exit
code, so the only symptom is a shorter list.

Louder than F3, and still not loud enough to stop a run.

### F5 — volume is a non-finding

Timed against hardlinked corpora, one project directory per multiple:

| files | wall clock |
|---|---|
| 100 | 1s |
| 200 | 3s |
| 400 | 4s |

The live archive (404 files, ~574 MB) runs the same path in **7.6s**. Growth is
sub-linear past the fixed git-history cost. Doubling — or quadrupling — keeps the
sweep inside its two-minute design budget with wide headroom.

Recording this deliberately: the cadence design worries about the sweep becoming
expensive, and on this evidence that is not the risk. The risk is that it is
confidently wrong while staying fast.

### F6 — the alert has no memory

The notifier is correctly registered (`launchctl print` resolves it, with the
artifacts root and a working `PATH`), and its dependencies all resolve under
launchd's environment. That is not the problem.

The problem is that **a fired alert, a failed alert, and an alert that never ran
are all the same on disk.** The script writes nothing on success. Its stderr log
does not exist — which reads as "never errored" and as "never ran," with no way
to tell them apart. There is one banner, at one moment, once a week: no repeat,
no escalation, no second recipient, no persistent artifact.

Verified end to end: a notify-mode run that hung and was killed left the state
directory **completely unchanged**. The failure was total and invisible.

Applied to the challenge's question — the reviewer out sick on run day — the
answer is that the week is simply skipped, and nothing anywhere records that it
was. The system is currently 7 days past its threshold and has notified no one.

### F7 — no timeout around the notifier

`terminal-notifier` is called with `|| true`, which handles a non-zero exit but
not a hang. Observed blocking past two minutes in a non-interactive context and
requiring a kill. `|| true` cannot rescue a process that never returns.

Lower severity — but note it shares F6's property: the hang left no trace.

### F8 — the ledger fragments across repositories, and only one half is read

The artifact convention keys on the **git remote name of the repo you are working
in**, so where a review runs decides where its ledger row is written. The read
side does not match:

```
find "$ART_ROOT" -mindepth 3 -maxdepth 3 -path '*/skill-reviewer/LEDGER.md' | head -1
```

`head -1` takes one file and discards every other. Tested with a ledger under
each of two repo keys:

| Unit | Truth | Reported |
|---|---|---|
| `fw-investigate` | reviewed 2026-08-26 | **absent entirely** |
| `investigate` | reviewed 2026-08-25 | **2026-08-12** — 13 days stale |

Both directions are silent, and the winner is decided by directory order, not by
date — so the same command can return different answers on different machines,
or after an unrelated rename.

The asymmetry is the tell. On the same root, in the same script, the artifact arm
scans **every** repo key (73 files across two here) while the ledger arm reads
one. Only the first policy is documented.

Underneath is a category error rather than a bug: **the ledger is not a per-repo
artifact.** It measures the skill system, which is machine-global — the same
units, the same thresholds, whatever repo the session happened to start in. It
inherited repo-keying from the generic artifact convention, where that keying is
correct and load-bearing.

Not currently firing: exactly one ledger exists, under the repo where the skills
are maintained. That is luck holding the line, not a defence.

- **Detection** — none. **Alert** — none. **Fallback** — none.
- **Catch before shipping** — run reviews from one repo, always. A convention no
  one has written down and nothing enforces.

## Recovery plays

Until the fix below lands, these are manual and belong to whoever runs the sweep.

| Mode | Detect | Fallback |
|---|---|---|
| F1, F2, F8 | **Now automatic** — read `ledger_status`. Anything other than `parsed:<n>` or `absent` is a defect the sweep reports under Inert. Re-pin with `inventory.sh --selftest`. | Treat every `last_reviewed` as null, say the staleness arm cannot fire, and let the run-count arm carry the cadence alone — the documented behaviour for a machine with no ledger. For `split`, move the named file to the canonical path; nothing reads it where it sits. |
| F3, F4 | Re-run the mining aggregate; compare `sessions` against the pre-filter's file count. Cross-check totals against `signals.sh --verify`. | Report counts as floors — which SKILL.md already requires — and do not score a prediction on a window containing an unexplained drop. |
| F8 | `find "$ART_ROOT" -path '*/skill-reviewer/LEDGER.md'` — more than one line is the defect. | Run every review from the repo where the skills are maintained, so all rows land in one file. |
| F6, F7 | Ask when the last `/system-review` ran. The absence of a notification is not evidence that none was due. | Run `sweep-due.sh --check` by hand; it is cheap, deterministic, and needs no GUI. |

Across every mode, one rule carries the most weight and needs no code: **a number
from this loop is not evidence for an edit until a second arm agrees with it.**
SKILL.md already says every count is a floor and every edit cites a run. F1 is
the case where that discipline is the *only* remaining defence.

## The gap worth fixing first — done

Implemented as described below. Kept as the record of why, since the next
operator's question will be "why is the ledger not where the artifact convention
says it should be", and this is the answer.

F1, F2 and F8 — the ledger arm, all three. Not because they are the largest
errors, but because they are the only ones that produce a **confidently wrong
value** rather than a low one, and because that value gates whether other skills
get reviewed at all. F3 deflates a number a careful reader might question; F1 and
F8 invent dates that look exactly like real ones.

Proposed, and deliberately small:

1. **Unpin the ledger from the repo key.** Store it at
   `$MY_CLAUDE_ARTIFACTS_ROOT/skill-reviewer/LEDGER.md` — one level above the
   per-repo layout — so fragmentation is unrepresentable rather than merely
   avoided. Keep a depth-3 scan solely to *warn* about strays left behind.
   Merging the halves instead would preserve the category error and leave N
   files to keep consistent.
2. **Anchor the date parse** to the token immediately following the em dash,
   rather than scanning the line for anything date-shaped. Kills the
   fall-through to the parenthetical outright.
3. **Emit `ledger_status`** in `--json`, distinguishing `absent`, `empty`,
   `unparsed`, `split:<n>`, and `parsed:<n>`. One field, and it is what separates
   F2 and F8 from a genuinely fresh machine.
4. **Treat `unparsed` and `split` as loud** — a ledger that exists and yields
   zero rows, or a second ledger under another key, is a defect the sweep should
   report rather than absorbing into a column of dashes.
5. **Add `--selftest` to the ledger parser**, with the fixtures used here
   (absent / empty / well-formed / off-convention date / two repo keys).
   Precedent exists: `signals.sh --verify` and the prose guard's selftest, which
   passes 13/13.

Deliberately *not* proposed: anything that makes the sweep slower. F5 shows the
budget is not the constraint, but a two-minute job is the only kind that survives
being weekly, and that property is worth protecting.

## Reproducing this

The harness builds ledger variants under a fake artifact root and corrupts copies
of real transcripts under a fake transcript directory. Both scripts already take
the env vars needed to redirect them — `SKILL_ARTIFACT_ROOT` and
`SKILL_TRANSCRIPT_DIR` — so no test needs to touch live data, and none did.

Re-run after any change to the ledger parse, the mining pipeline, or the notifier.
