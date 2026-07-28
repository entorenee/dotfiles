---
name: config-health
description: Use for a periodic health check of the Claude Code harness itself — settings.json symlink integrity, skill/command allowlist drift, dead permission rules, hook registration, plus the permission-audit and fewer-permission-prompts analyses merged into one classified report. Orchestrates config-level checks only; NOT for product-code health (dead-code-survey, npm-cve, error-triage).
---

# Config Health

An orchestrator over the checks that tell you whether this **Claude Code
installation** is working as configured — not whether your product code is
healthy. It runs four deterministic config checks, fans out the two
transcript-analysis skills, and merges everything into one report where every
finding carries its evidence class and its fix.

This skill is **read-only except for Nix files you approve at the end.** It
never writes `~/.claude/settings.json` (a read-only Nix store symlink), never
runs `make rebuild`, and never commits.

## When to Use

- A periodic "is my setup still sound?" pass.
- Permission prompts feel excessive and you want the full picture, not one angle.
- After adding several skills, commands, or hooks — drift accumulates silently.
- Before deciding whether to tighten permission mode.

## When NOT to Use

- One specific question about permission mode → `permission-audit` directly.
- Building an allowlist on a **new machine** with no history → `fewer-permission-prompts`.
- Changing one setting or adding one hook → `update-config`.
- Product-code health (`dead-code-survey`, `npm-cve`, `dependency-upgrades`,
  `error-triage`) — deliberately out of scope. Folding those in produces a
  report nobody acts on.

## Workflow

```dot
digraph config_health {
  rankdir=TB;
  "0. Insights pre-step (opt-out)" -> "1. Deterministic checks (inline)";
  "1. Deterministic checks (inline)" -> "2. Build shared corpus once";
  "2. Build shared corpus once" -> "3. Fan out: 2x sonnet subagents";
  "3. Fan out: 2x sonnet subagents" -> "4. Classify + rank (main, opus)";
  "4. Classify + rank (main, opus)" -> "5. Report";
  "5. Report" -> "6. Offer Nix edits (confirmation-gated)";
}
```

## Step 0 — `/insights` pre-step

`/insights` is a **built-in slash command, not a skill** — no tool can invoke it,
and it leaves no report file on disk to read afterward. So it has to come from
the user, and it has to come *first*.

Open with `AskUserQuestion`:

- **Include insights (recommended)** — ask the user to run `/insights` now and
  let its report land in the conversation. Then continue. Its session-level
  friction counts (`user_rejected`, `wrong_approach`) are the only *behavioural*
  evidence in the whole report; without them, every finding is structural.
- **Skip insights** — proceed without it. Record the omission in Coverage.

Hand over the literal command to run — `/insights` — rather than describing it.
If the user picks include, **wait**; do not start Step 1 and circle back, because
the insights numbers change how Step 4 classifies behavioural findings.

Do not reimplement `/insights` by recomputing its counts from transcripts. It
would drift from whatever the real command measures, and a number that disagrees
with the tool the user actually trusts is worse than a stated gap.

## Step 1 — Deterministic checks (inline, no subagent)

```bash
bash "$HOME/.claude/skills/config-health/config-checks.sh"
```

Output is `STATUS<TAB>CHECK<TAB>DETAIL`, where `STATUS` is `OK`, `FAIL`
(provably broken), or `REVIEW` (needs human eyes — the script deliberately
refuses to decide). Four checks: settings.json symlink integrity, skill/command
↔ `Skill()` allowlist drift, allow rules neutralised by deny, and hook
registration + executability.

**Run these inline. Do not dispatch a subagent for them.** They read a handful of
small files; agent dispatch would cost more than it saves *and* insert a
summarizing layer between you and ground truth — the exact failure mode that
turns a verifiable fact into an overstated claim.

These are the highest-value findings per token in the whole skill, because each
one is a **silent** failure: a missing settings.json takes every permission rule
with it, an unregistered hook simply never fires, a non-executable hook fails
with no error. Nothing surfaces them at the moment they break.

Trust the script's own tiering. A `REVIEW` line is not a finding you may promote
to `FAIL` by reasoning about it — verify it against the file or report it as
review.

## Step 2 — Build the shared corpus once

Both analysis skills scan `~/.claude/projects/**/*.jsonl`. That is the single
largest cost in this skill, and running it twice is pure waste. Build the tagged
corpus once, into scratchpad:

```bash
SK="$HOME/.claude/skills/permission-audit"
OUT="<scratchpad>/tagged.json"
cd "$HOME/.claude/projects" && find . -name '*.jsonl' -print0 \
  | xargs -0 cat 2>/dev/null | jq -s -f "$SK/mode-attribution.jq" > "$OUT"
```

The corpus is a file path, so it costs nothing in context regardless of size.
Pass `$OUT` to both subagents in Step 3.

`permission-audit` consumes this directly (it is that skill's own Step 1 output).
`fewer-permission-prompts` is a built-in with its own methodology — tell its
subagent the corpus exists and to prefer it, but treat reuse there as best-effort
and do not claim the scan was deduplicated if it re-scanned anyway.

## Step 3 — Fan out (two `sonnet` subagents, read-only)

Dispatch both in a **single message** so they run concurrently.

| Subagent | Model | Tools | Returns |
|---|---|---|---|
| Runs `permission-audit` | `sonnet` | `Bash, Read, Grep, Glob` | Raw findings: counts, example commands, denial→replacement pairs |
| Runs `fewer-permission-prompts` | `sonnet` | `Bash, Read, Grep, Glob` | Candidate allow patterns with frequencies |

**Why `sonnet`:** both steps are mechanical extraction over a large corpus —
run committed `jq`/`grep`, tabulate, return examples. High volume, low judgment.
This matches the tiering the rest of this config already uses (`investigate`'s
verification runner, `npm-cve`'s researchers, all three custom agents). The
reasoning worth paying for is classification and ranking, and that stays in the
main `opus` context in Step 4.

**Read-only tools are a structural guard, not a courtesy.** Omit `Edit` and
`Write` from both. `fewer-permission-prompts` writes project
`.claude/settings.json` as its final step — under Nix that either fails or
creates a shadow config that silently overrides the declarative one. Denying the
tool prevents it; an instruction not to write only asks nicely.

**Instruct both subagents to stop before their terminal prompts.** Each skill
ends by asking the user to apply its findings. A subagent cannot prompt the user,
so that step either dies or turns into a silent write. Tell each one explicitly:
return findings, apply nothing, prompt for nothing. This skill owns the single
consolidated prompt in Step 6.

**Do not let either subagent classify or rank.** They return raw findings and
counts. See Step 4 for why.

## Step 4 — Classify and rank (main context, `opus`)

Sort every finding — from all three sources — into exactly one bucket. This is
`permission-audit`'s Step 3 rule, applied report-wide because findings now arrive
from four places instead of one:

- **Missing allowlist entry** — a legitimate operation with no matching rule.
  Fix: propose a narrow `permissions.allow` pattern.
- **Behaviour to correct** — an operation that violates a documented rule and
  should never have been issued (`node -e` to read a file, relative
  `node_modules/.bin/` paths). Fix: **do not allowlist it.** These prompt
  *correctly*. A high count means auto mode suppressed the feedback that would
  have corrected the habit; the remedy is a CLAUDE.md rule or a hook.
- **Config defect** — a Step 1 `FAIL`. Fix: repair the Nix config.

Misfiling the second bucket as the first is the primary failure mode of this
skill, and its blast radius is larger than `permission-audit`'s alone: it
converts a behavioural problem into permanently loosened permissions across the
whole config. This is why the ranking call never goes to a cheaper tier.

Then tag each finding with its **evidence class**, and keep the classes visually
separate in the report:

| Class | Source | How to state it |
|---|---|---|
| **Fact** | Step 1 checks | Assert plainly. Verified off disk. |
| **Inference** | permission-audit, fewer-permission-prompts | *Always* hedged. See below. |
| **Behavioural** | `/insights`, denial→replacement pairs | Points at a rule or hook, never at a permission. |

**The inference caveat is mandatory and non-negotiable.** An approved permission
prompt leaves *no trace whatsoever* in the transcripts. You therefore cannot
count prompts you approved — every frequency claim from Steps 2–3 is inferred
from rule matching, never measured. State this in the report body, not only in a
footnote. Two prior sessions in this repo asserted a prompt cause with no
recorded denial and shipped a workaround for a non-problem.

Before asserting that any pattern prompts, require either a **recorded denial**
or an **observed prompt from running a harmless variant.** The permission engine
is more permissive than folklore suggests: `cd <path> && cmd`, `cmd 2>&1 | tail`,
`cmd > file`, and `mkdir -p … && cmd` all auto-approve when each segment is
allowlisted or built-in read-only. Chaining alone does not force a prompt.

## Step 5 — Report

Write to `.claude/local-docs/config-health/YYYY-MM-DD-config-health.md` in the
dotfiles repo, and summarize inline. Order sections by actionability:

1. **Config defects (facts)** — Step 1 `FAIL` lines, each with its one-line fix.
   Lead here: provable, cheap to fix, silent until checked.
2. **Review items** — Step 1 `REVIEW` lines. Say what the script could not decide
   and what the user should look at.
3. **Missing allowlist entries (inferred)** — ranked by count, each with a real
   example command and the proposed narrow pattern. Carries the caveat.
4. **Behaviour to correct** — with the proposed CLAUDE.md rule or hook. Never a
   permission change.
5. **Coverage** — whether `/insights` was included or skipped, which tier ran the
   fan-out, whether the corpus was shared or re-scanned, and anything not checked.

Report **every** finding. If you pare the apply-list down in Step 6, the full
list still lives here so nothing is silently dropped.

The artifact is git-ignored and uncommitted — never stage or commit it.

## Step 6 — Offer the fixes (confirmation-gated)

Use `AskUserQuestion` to offer applying only the **highest-value** items: config
defects first, then missing-allowlist entries with real counts behind them. Apply
only what is approved.

- Permissions and hook registrations live in `nix/module/claude/default.nix`
  (base) or `work.nix` / `personal.nix` (profile-specific). **Never** write
  `~/.claude/settings.json`.
- Any allow pattern surfaced by `fewer-permission-prompts` gets redirected into
  Nix — never into a project `.claude/settings.json`.
- Never propose `permissions.deny` changes. Check every proposal against the
  existing deny list first: deny wins, so a contradictory allow entry is dead
  weight on arrival (and Step 1's `dead-allow` check will flag it next run).
- Adding a skill or command means adding its `Skill(<name>)` entry in the same
  change, or Step 1 flags it next run.

**Stop at the commit boundary.** Report which files changed and stop. Leave
`make rebuild` to the user — a rebuild while any session is live deletes
`settings.json` and every permission rule with it.
