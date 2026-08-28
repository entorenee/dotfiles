---
description: Weekly sweep of the skill system — what ran, what crossed its review threshold, what went quiet. Reports what is due and stops.
argument-hint: [optional — a unit name to check just that one]
---

# /system-review

The cheap tier of the skill-review loop. This command **reports what is due and stops.** It does not review anything, does not read a transcript for gate evidence, and does not edit a skill.

That restraint is the whole design. A sweep that quietly turns into a review takes a session instead of two minutes, and a two-minute job is the only kind that survives being weekly — `/reflect` ran once in 288 sessions because it needed the user to remember at the right moment, and this would go the same way if it ever felt expensive.

## 1. Read the state

```bash
bash "$HOME/.claude/skills/skill-reviewer/inventory.sh" --json
bash "$HOME/.claude/skills/skill-reviewer/signals.sh" --aging
bash "$HOME/.claude/skills/skill-reviewer/signals.sh" --since <date of the oldest unscored prediction>
bash "$HOME/.claude/skills/skill-reviewer/signals.sh" --hooks
bash "$HOME/.claude/hooks/prose-budget-guard.sh" --selftest
```

Five commands, and that is the whole data-gathering step. The second reads the friction log rather than the transcripts, so it costs nothing and feeds only the Aging bucket. The third is skipped entirely when `rollups/PREDICTIONS.md` has no unscored prediction. The fourth feeds the Inert bucket. The fifth takes about a second and answers the question the fourth cannot: `--hooks` says whether a guard *fired*, the selftest says whether it is still *correct*. A guard can be live and wrong. Report a nonzero exit as a defect under Inert — a failing selftest means the guard's behaviour has drifted from what it was built to do, which is worth more than any count in this sweep. Skip either and its bucket cannot be reported at all. Every field the buckets need is in one of the three, already computed:

| Field | Use |
|---|---|
| `sessions` | Real runs. The only count that makes a unit reviewable. |
| `subagent` | Sidechain invocations. Real uses, no human, never runs. |
| `runs_since` | Runs against the *current* text — runs after `changed`. **This is what the run arm applies to**, and it is per-host: transcripts do not sync, so never sum it across machines. |
| `changed` / `changed_subject` | When the unit last changed, and the commit subject. |
| `last_run` | For the Quiet bucket. |
| `reviewed_anywhere` | Newest commit carrying a `Reviewed-on:` trailer for the unit, from **any** host. **This is what the 45-day staleness arm measures from** — it rides the commits, so it needs no ledger. `null` means never reviewed anywhere, and the arm then counts from `changed`. `review_arm_status` says whether that null is expected. |
| `reviewed_host` / `reviewed_runs` | The host that ran that review and how many runs it analyzed. Report both when the staleness arm fires; a review done elsewhere left no local evidence behind. |
| `review_arm_status` | Top-level, not per-unit. `no-trailers-since:<date>` means the arm is live and nothing has carried a trailer since it shipped on that date — **the expected state, not a defect**, and never grounds for overriding the arm. `no-repo` means it could not run. `parsed:<n>` means n units carry one. |
| `last_reviewed` | Newest ledger row on *this machine*. Context only — **no arm measures from it**, so it can never be used to talk a unit off the Due list. `ledger_status` says why it is null. |
| `ledger_status` | Top-level, not per-unit. `absent`/`empty` explain a `null` `last_reviewed` honestly; `unparsed` or `split:<n>` mean a populated ledger went unread — a defect, reported under Inert. |
| `artifact_runs` | Dated reports. `artifact_files` includes CSV/SQL byproducts; do not read it as a run count. |
| `verdict` | Pre-computed coverage class. |

**Do not re-derive any of this by hand.** An earlier sweep answered "what is due" with a per-unit pipeline over `git log --follow` and `mine.jq`, which is precisely the cost that kills a weekly habit — `/reflect` ran once in 288 sessions for the same reason. If a number you need is missing, add it to `inventory.sh`; do not rebuild it in the sweep.

**Check `changed_subject` before trusting `runs_since`.** A repo-wide move or a path rewrite counts as a content change to git and resets the counter, but is not a revision — the skill's own rules say a commit is not a tightening until you have read what it changed. When the subject looks mechanical (`lift nix/ to the repo root`, `adjust skills to use ARTIFACTS`), say so and treat the unit's real clock as older.

The ledger is read from one canonical path, `$MY_CLAUDE_ARTIFACTS_ROOT/skill-reviewer/LEDGER.md` — **not** `$ARTIFACTS`, which expands to `$MY_CLAUDE_ARTIFACTS_ROOT/<repo>` and partitions the ledger on cwd. It is machine-local and lives outside the repo, so on a new machine there simply is not one — say so when `ledger_status` is `absent` or `empty`, and read review history off `reviewed_anywhere`, which is identical on every machine. A missing ledger no longer hides a review or stalls an arm. Under any other status that sentence is false; see Inert.

Thresholds live in `skill-reviewer/SKILL.md` under **Cadence and thresholds**. Read them there and apply them to `runs_since` and `reviewed_anywhere` yourself; do not restate them here or bake them into a script, or the two will drift and the sweep will start enforcing a rule nobody agreed to.

## 2. Sort every unit into exactly one bucket

| Bucket | Meaning |
|---|---|
| **Due** | Crossed its threshold, counting runs since the commit that last changed it. |
| **Accumulating** | Has runs, not yet at threshold. Report the count, not a recommendation. |
| **Below the floor** | Under 3 runs recorded *here* — runs are per-host and never summed. Not reviewable on run evidence, though the staleness arm can still make it Due. |
| **Quiet** | Had runs here in an earlier window and none recently; say "on this machine", since another host's use is invisible. Worth a mention — a skill that stopped being used is a finding, and the only one this sweep can make on its own. |
| **Declined** | Verdict `unadopted`. Asked and answered — see below. |
| **No evidence** | Verdict `no-evidence`: nothing in any arm. See below, because this bucket has burned us twice. |
| **Aging** | Friction entries still at `Class: open` past the threshold — the lesson never became executable. From `signals.sh --aging`. See the cap below; this bucket has a backlog problem the others do not. |
| **Predictions** | An instruction-text change whose measured outcome is now readable. From `signals.sh --since`, banded in `rollups/PREDICTIONS.md`. **The only bucket that can report something learned rather than something due.** |
| **Inert** | A registered hook with `FIRED=0`, or one whose `LAST` predates this window. From `signals.sh --hooks`. A hook on the `Bash` matcher is paid on every Bash call, so one that never fires is pure overhead — recommend removal, not tuning. Read an absent row as "produced no output", never as "never ran": a hook that passes silently emits nothing, so the deny-guards live in `--denials` instead and are not expected here. A `ledger_status` of `unparsed` or `split:<n>` is a defect reported here too — both once produced a column of dashes indistinguishable from a fresh machine, so the sweep announced "this machine has no ledger" while a populated one sat unread. A `review_arm_status` of `no-repo` belongs here as well; `no-trailers-since:<date>` does **not** — on 2026-08-27 the first sweep after that arm shipped reported the arm's own zero as an instrument defect, which is what the status field now exists to prevent. |

Sort on the `verdict` field, not on whether a count looks empty. `unadopted` and `no-evidence` both show zero sessions and are the same shape at a glance, but they are opposite states: one is a question already closed, the other is a question never asked.

**`unadopted` is closed. Do not re-ask it.** The verdict exists precisely because the user has already said the unit has not run, and that answer is recorded in `skill-reviewer/testimony.txt` so it survives. Report it under Declined and move on. Putting it back in the "Ask about" line re-opens a question `testimony.txt` was created to close, which is the exact loop that file exists to break.

**A prediction outside its band opens a discussion. It never fires a removal.** Read the band from `rollups/PREDICTIONS.md` — like every other threshold, it is not baked into the script. Then:

- **Below the review threshold** (`typed turns` under the prediction's n) → report "not yet due" and nothing else. Do not score early, and **do not move the threshold**; if the window genuinely needs changing, that is a new prediction with a new baseline, not an edit to the existing one.
- **Inconclusive** → say so plainly. **This is the expected outcome**, not a non-answer. Note how many consecutive reviews have been inconclusive; at three, the discussion opens anyway, starting from "remove".
- **Outside the band in either direction** → raise it with the recommendation and the evidence, and stop. The decision is the user's.

Automatic deletion on a failed prediction is the wrong default while the system is maturing: it removes rules on noisy evidence, and because that feels bad, the real response becomes quietly extending the window — worse than either honest option. Raising it here is also what gives this sweep a second kind of finding; without it the sweep can only ever report what is *due*, never what has been *learned*.

**Ask what the user actually experienced, and write the answer down.** This is a required input to the discussion, not a courtesy, and it is the only evidence available for a **known, non-random blind spot**: the metric cannot see a wrong proposal corrected purely in prose — no edit, no rejected call — which is exactly the case the rule was written to fix. Measured in the session where the metric was designed, it caught one such failure and missed one. A discussion held on the number alone is therefore biased toward whatever the structural arms happen to catch, and confidently so.

Record the answer under the prediction in `rollups/PREDICTIONS.md`, verbatim enough to be re-read later. `testimony.txt` is the precedent and the reason: it exists because the user's memory is *"the only record that is not re-derivable"*, and losing it means asking the same question twice — which has already happened here. Spoken testimony that is not written down is gone by the next review, and the next review will ask again.

Two guards, both learned the hard way in this repo. An anecdote is **evidence about the tool, never about a person's judgment**. And where the account and the metric disagree, **report both and resolve neither** — a conflict is a finding, and flattening it into agreement is how a confident wrong answer gets made.

**Always report the gaming check alongside the rate.** If rework falls while `interrupts` and `lexical` hold steady or rise, the likely explanation is the metric being gamed — re-editing less rather than being wrong less. Say that instead of banking the improvement.

**The Aging bucket reports a COUNT plus the oldest three. Never the full list.** Twenty of the current entries were back-filled on two days in 2026-08, so they cross any threshold together — a bucket that prints everything past the line will one morning print twenty rows into a sweep whose entire reason for existing is that it takes two minutes. The count carries the signal; three examples carry the texture.

`--aging` deliberately applies **no threshold** — it emits an `AGE` column and stops, because thresholds live in `skill-reviewer/SKILL.md` and a number baked into a script drifts from the one that was agreed. Apply the 45-day arm yourself, the same way you already do for `runs_since`.

Two rows to read carefully rather than skim: `Class: MISSING` is a pre-migration entry with no `Class` line — a defect in the entry, not an aging signal. And an entry can sit at `Status: resolved` with `Class: open` indefinitely, which is not a contradiction: the instance was fixed and the lesson never became executable. **That combination is the normal state, not an anomaly** — 21 of 22 entries were `Class: open` at migration and none had ever reached `graduated`.

**`no-evidence` means not measured.** It has never once meant "unused" when checked. Twice now an inventory reported units as never used and the user corrected it — three composed skills on 2026-08-12, then `regression-analysis`, an entry point nothing composes, on 2026-08-17. Report the bucket, ask, and write the answer into `skill-reviewer/testimony.txt` so the next sweep inherits it. Do not carry a unit into a "consider deleting" list off this bucket alone.

## 3. Report

Lead with the answer to the only question being asked:

```
Due now:      <unit> — <runs_since> runs since <changed>; or <n> days since
              <reviewed_anywhere> on <reviewed_host> (<reviewed_runs> runs), or
              since <changed> when never reviewed anywhere. Or "nothing".
Accumulating: <unit> <runs_since>/<threshold>, ...
Quiet:        <unit>, last run <last_run>
Declined:     <unit> — unadopted per testimony. Not a question.
Ask about:    <unit> — no evidence in any arm
Clock reset:  <unit> — <changed_subject> looks mechanical, not a revision
Aging:        <n> entries open past threshold; oldest F<x> (<d>d), F<y>, F<z>
              — or "none". Add "<m> never graduated" only when it changes.
Prediction:   P<n> <rate>% vs band <lo>-<hi>% — improved | inconclusive (<k>x) |
              outside band, discuss. Or "not yet due (<t>/<n> turns)".
              When discussing: ask what they experienced, and write it into
              PREDICTIONS.md under that prediction before the decision.
Ledger:       <ledger_status> — omit the line when it is `parsed:<n>`
Review arm:   <review_arm_status> — omit when `parsed:<n>`. Under
              `no-trailers-since:<date>` say the arm is live and unexercised,
              and that every staleness clock therefore counts from `changed`.
Config:       <any FAIL from config-checks.sh skill-inventory, if it was run>
```

Say which arm made something due — the run count or the staleness clock — and on the staleness arm name `reviewed_host`. They imply different reviews: fresh local runs mean there is new gate evidence to mine, whereas a stale clock usually means there is not. When the last review ran on another host, say so and expect little or no local evidence: those runs are on a machine whose transcripts you cannot read, so the review is re-reading text. Under `ledger_status: absent` or `empty`, say the machine has no ledger once rather than on every line; under `unparsed` or `split` that claim is false, so report the defect instead.

**"Nothing is due" is a complete and successful run.** Do not pad it with observations to look productive; the sweep is worth having precisely because it is usually empty.

## 4. Offer, do not start

If something is due, name it and stop. Reviewing it is a separate, user-initiated session — invoke `skill-reviewer` then, not now. If several units are due at once, recommend one and say why; a review that covers three units produces three shallow ledger rows.
