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
```

That is the whole data-gathering step. Every field the buckets need is in it, already computed:

| Field | Use |
|---|---|
| `sessions` | Real runs. The only count that makes a unit reviewable. |
| `subagent` | Sidechain invocations. Real uses, no human, never runs. |
| `runs_since` | Runs against the *current* text — runs after `changed`. **This is the number the thresholds apply to.** |
| `changed` / `changed_subject` | When the unit last changed, and the commit subject. |
| `last_run` | For the Quiet bucket. |
| `artifact_runs` | Dated reports. `artifact_files` includes CSV/SQL byproducts; do not read it as a run count. |
| `verdict` | Pre-computed coverage class. |

**Do not re-derive any of this by hand.** An earlier sweep answered "what is due" with a per-unit pipeline over `git log --follow` and `mine.jq`, which is precisely the cost that kills a weekly habit — `/reflect` ran once in 288 sessions for the same reason. If a number you need is missing, add it to `inventory.sh`; do not rebuild it in the sweep.

**Check `changed_subject` before trusting `runs_since`.** A repo-wide move or a path rewrite counts as a content change to git and resets the counter, but is not a revision — the skill's own rules say a commit is not a tightening until you have read what it changed. When the subject looks mechanical (`lift nix/ to the repo root`, `adjust skills to use ARTIFACTS`), say so and treat the unit's real clock as older.

The ledger is at `$ARTIFACTS/skill-reviewer/LEDGER.md`; it is machine-local and lives outside the repo, so on a new machine there simply is not one — say so rather than treating every unit as never-reviewed.

Thresholds live in `skill-reviewer/SKILL.md` under **Cadence and thresholds**. Read them there and apply them to `runs_since` yourself; do not restate them here or bake them into a script, or the two will drift and the sweep will start enforcing a rule nobody agreed to.

## 2. Sort every unit into exactly one bucket

| Bucket | Meaning |
|---|---|
| **Due** | Crossed its threshold, counting runs since the commit that last changed it. |
| **Accumulating** | Has runs, not yet at threshold. Report the count, not a recommendation. |
| **Below the floor** | Under 3 recorded runs. Not reviewable. |
| **Quiet** | Had runs in an earlier window and none recently. Worth a mention — a skill that stopped being used is a finding, and the only one this sweep can make on its own. |
| **No evidence** | Nothing in any arm. See below, because this bucket has burned us twice. |

**`no-evidence` means not measured.** It has never once meant "unused" when checked. Twice now an inventory reported units as never used and the user corrected it — three composed skills on 2026-08-12, then `regression-analysis`, an entry point nothing composes, on 2026-08-17. Report the bucket, ask, and write the answer into `skill-reviewer/testimony.txt` so the next sweep inherits it. Do not carry a unit into a "consider deleting" list off this bucket alone.

## 3. Report

Lead with the answer to the only question being asked:

```
Due now:      <unit> (<runs_since> runs since <changed>)   — or "nothing"
Accumulating: <unit> <runs_since>/<threshold>, ...
Quiet:        <unit>, last run <last_run>
Ask about:    <unit> — no evidence in any arm
Clock reset:  <unit> — <changed_subject> looks mechanical, not a revision
Config:       <any FAIL from config-checks.sh skill-inventory, if it was run>
```

**"Nothing is due" is a complete and successful run.** Do not pad it with observations to look productive; the sweep is worth having precisely because it is usually empty.

## 4. Offer, do not start

If something is due, name it and stop. Reviewing it is a separate, user-initiated session — invoke `skill-reviewer` then, not now. If several units are due at once, recommend one and say why; a review that covers three units produces three shallow ledger rows.
