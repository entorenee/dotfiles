---
name: permission-audit
description: Use when deciding whether a stricter permission mode is viable, or when permission prompts feel excessive — attributes every historical tool call to the permission mode in effect, surfaces which auto-mode calls would have prompted under acceptEdits, and pairs recorded denials with the command that replaced them. Evidence-based, not frequency-based; complements fewer-permission-prompts.
---

# Permission Audit

Answers two questions the frequency-based `fewer-permission-prompts` skill cannot:

1. **What is my auto-mode habit hiding?** Which calls sailed through under `auto`
   that would have stopped in `acceptEdits` — so you know the real cost of
   tightening the mode before you switch.
2. **Where did a denial actually cost me a round trip?** Which denied commands
   were followed by an approved replacement.

Do not use this to build an allowlist from scratch on a new machine — with no
history there is nothing to attribute. Use `fewer-permission-prompts` for that.

## What the data does and does not contain

Read this before making any claim about prompts. Getting it wrong produces
confident, wrong diagnoses — which has already happened in this repo.

| Event | Recorded? | Where |
| --- | --- | --- |
| Mode switch | Yes | `permission-mode` entry, `.permissionMode` |
| Mode in effect on a user turn | Yes | `user` entry, `.permissionMode` |
| Mode in effect on a **tool call** | **No** — must be carried forward | — |
| Prompt shown and **approved** | **No — leaves no trace whatsoever** | — |
| Denial of any kind | Yes | `user` entry, **`.toolDenialKind`** |

The critical consequence: **you cannot count prompts you approved.** Any claim
about how often something prompted is an inference from rule matching, never a
measurement. Say so in the report.

### Read denials from `.toolDenialKind`, never from result text

The field is structural and carries five values: `permission-rule`,
`user-rejected`, `automode-blocked`, `automode-unavailable`, `interrupted`.

Grepping result text for `has been denied` / `doesn't want to proceed` is wrong
in both directions, and tempting enough that it needs refuting once. Measured
2026-08-26 over the whole archive: 101 structural denial events, of which
text-matching finds 74 and **invents 18 more** that carry no `toolDenialKind`
at all (transcript prose quoting the phrase). What it misses is not random:

| Missed | Why the text match fails |
| --- | --- |
| 21 `permission-rule` | Hook denials read *"python -c is denied: …"* — no `has been denied` substring |
| 4 `automode-blocked` | Reads *"was denied by the Claude Code auto…"* |
| 1 `automode-unavailable` | Model-unavailable fallback, different wording entirely |
| 1 `interrupted` | `[Request interrupted by user for tool use]` |

Every hook denial is in the missed set, so the text match is blind to exactly
the population that must *never* be allowlisted. That is the failure mode this
skill exists to prevent.

## Step 1 — Attribute modes

Concatenate every transcript and run the committed attribution script. Group by
`sessionId`, not by file, so subagent sidechains are handled and file order is
irrelevant.

```bash
SK="$HOME/.claude/skills/permission-audit"
OUT="<scratchpad>/tagged.json"
cd "$HOME/.claude/projects" && find . -name '*.jsonl' -print0 \
  | xargs -0 cat 2>/dev/null | jq -s -f "$SK/mode-attribution.jq" > "$OUT"
```

Report the population before analysing it, so the denominator is explicit:

```bash
jq -r '[.[] | select(.name=="Bash")] | group_by(.mode)[] | "\(.[0].mode)\t\(length)"' "$OUT"
```

## Step 2 — Find the auto-mode free passes

Extract commands that ran under `auto`, then match **whole commands** against
the blocker patterns below.

```bash
jq -r '.[] | select(.name=="Bash" and .mode=="auto") | .cmd' "$OUT" > "$SCRATCH/auto.txt"
```

**Do not split commands into segments and tokenize.** Splitting on `;`, `|`,
and `&` shreds heredocs and quoted strings, and reports embedded JavaScript and
test output as if they were commands (`console.log`, `const`, `FAIL` all show up
as "leading tokens"). Match the whole command string instead.

Blocker patterns, each confirmed against a real denial or an explicit CLAUDE.md
rule — never add a speculative one:

| Pattern | Why it blocks |
| --- | --- |
| `node_modules/\.bin/` | Relative bin path matches no allow rule |
| `node -e`, `python3? -c` | Arbitrary code execution; unallowlistable by design |
| `(^\| )rm ` | No allow rule; `rm -rf` additionally denied |
| `(^\| )touch `, `chmod `, `mv ` | Mutating, no allow rule |
| `<<` | Heredoc — the body is opaque to the matcher |
| `^for `, `^while ` | Shell loop, not a matchable command |
| `pnpm dlx`, `npx` (unpinned pkg) | Arbitrary package execution |
| `npm pack` | Mutating, no allow rule |

```bash
for p in 'node_modules/\.bin/' 'node -e' 'python3? -c' '(^| )rm ' '<<' '^for '; do
  printf '%-26s %s\n' "$p" "$(grep -cE "$p" "$SCRATCH/auto.txt")"
done
```

## Step 3 — Classify each finding by its actual fix

Sort every hit into the bucket that determines its remedy — they call for
opposite responses:

- **Missing allowlist entry.** A legitimate command with no matching rule
  (e.g. a read-only tool that simply was never added). Fix: propose a narrow
  `permissions.allow` pattern.
- **Behaviour to correct.** A command that violates a documented rule and
  should never have been issued (`node -e` for file inspection, relative
  `.bin/` paths). Fix: **do not allowlist it.** These prompt *correctly*. A high
  count here means auto mode suppressed the feedback that would have corrected
  the habit — the remedy is a CLAUDE.md rule or a hook, never a broader allow.
- **Sandbox boundary.** No allow rule can bypass it. Changing it means editing
  `sandbox.filesystem.*`, which is a hardening decision, not a convenience fix.

Misfiling the second bucket as the first is the main failure mode of this
skill: it converts a behavioural problem into permanently loosened permissions.

**For anything with a recorded denial, do not classify by hand — the bucket is
already structural.** `signals.sh --denials` (step 4) derives it from
`.toolDenialKind` plus the denial text: `allowlist-gap`, `hook-deny`,
`sandbox-deny`, `user-rejected`. Hand classification is only for step 2's
*inferred* blockers, which by definition have no denial to read.

## Step 4 — Census the denials, then pair them with their replacements

The census is already built. Do not re-derive it, and do not grep result text:

```bash
bash "$HOME/.claude/skills/skill-reviewer/signals.sh" --denials
```

It groups every denial by `.toolDenialKind`, classifies each into the step-3
buckets, and prints the commonest command shapes per bucket with a footer
saying what each bucket's remedy is. It includes subagent sidechains, which the
session table excludes — a rule that blocks a subagent still needs fixing, and
8 of the rule denials are sidechain-only.

Then pair the interesting ones. The census reports shapes, not sequences, so
this part is still yours to run — select structurally, never on text:

```bash
cd "$HOME/.claude/projects" && find . -name '*.jsonl' -print0 | xargs -0 cat 2>/dev/null \
  | jq -rs 'map(select(.toolDenialKind != null))
            | .[] | "\(.sessionId)\t\(.toolDenialKind)"'
```

For each denial, find the next `Bash` call in that session and report the pair.
The delta is the signal — it shows what actually satisfied you, which is better
evidence than any rule analysis. Expect low volume; a handful of these often
beats a long frequency table.

## Step 5 — Verify before asserting

For any finding where the matching outcome is not obvious, **run a harmless
variant and observe whether it prompts.** The permission engine is more
permissive than folklore suggests — verified: `cd <path> && cmd`, `cmd 2>&1 |
tail -40`, `cmd > file`, and `mkdir -p … && cmd` all auto-approve when each
segment is allowlisted or built-in read-only. Chaining alone does not force a
prompt.

Never state that a pattern prompts without either a recorded denial or an
observed prompt. Two separate sessions in this repo wrongly blamed a `cd …`
prefix and shipped a workaround for a non-problem.

## Step 6 — Report, then prompt on the top findings

Report all findings; ranked by count, each with a real example command and its
bucket from step 3. State the inference caveat from the top of this file.

Then use `AskUserQuestion` to offer applying **only the highest-value
findings** — the ones in the "missing allowlist entry" bucket with a real count
behind them. Apply only what is approved.

- Permissions live in `modules/home/claude/default.nix` (base),
  `hosts/darwin/fw-skyler/claude.nix` (work), or
  `roles/home/personal-claude.nix` (personal) — an identity is a file the host
  imports, not a profile string to branch on. Never write
  `~/.claude/settings.json`; it is a read-only Nix store symlink.
- Never propose `permissions.deny` changes. Check proposals against the
  existing deny list, since deny wins and a contradictory allow entry is dead
  weight.
- Leave `make rebuild` to the user; report which files changed.
