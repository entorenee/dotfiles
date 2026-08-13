---
name: comment-review
description: Use when reviewing or cleaning up code comments — whether a codebase has accumulated redundant commentary, a diff adds explanatory comments worth vetting, or comments have drifted out of sync with the code. Language-agnostic. Judges each comment by attachment (does it describe the thing it sits on) rather than length, and surfaces comments that are factually wrong. Usable standalone or invoked by the code-hygiene skill.
---

# Comment Review

## Overview

Comments rot for one reason: nothing forces them to stay true. A comment that
sits on the line it describes gets re-read whenever that line changes. A comment
that describes something *elsewhere* — a system-wide convention, another file's
contents, a policy already written in the project's docs — is never re-read at
the moment it becomes false.

This skill separates those two kinds and removes the second. It is **not** a
"make comments shorter" pass. Length is not the defect.

## When to Use

- A codebase has accumulated redundant or duplicated commentary
- Reviewing a diff that adds explanatory comments
- After a large refactor, when comments may describe the old shape
- When invoked by the `code-hygiene` skill (diff-scoped mode)

## When NOT to Use

- Writing new documentation (this only reviews what exists)
- API/docstring generation
- As a pretext for behavior changes — see the hard rule below

## The Test: Attachment, Not Length

For each comment ask: **does this describe the thing it sits on, or does it
describe something global from a local vantage point?**

**Anchored** — explains the very line, block, option, or absence it sits next to.
Keep it, *even if it is long*. It is at the source, so whoever edits the code has
it in front of them and can correct it in the same edit. A 10-line comment
explaining a non-obvious workaround directly above that workaround is correct.

**Detached** — restates a system-wide convention, another module's contents, or a
policy the project's own docs already carry. Nothing local keeps it honest, so it
is what actually rots. A comment ending in "see CONTRIBUTING.md" / "see the docs"
is usually admitting it is this kind.

> **Comment ratio is never the target.** A file that is 60% comments may be
> entirely correct if every line is anchored. Do not optimize the number.

## Four Buckets

| Bucket | Test | Action |
|---|---|---|
| **Keep** | Anchored: a local constraint, a hard-won gotcha, a magic-value decode, or an actionable maintenance recipe. Something breaks if it is deleted. | Keep. Compress wording only. **Length is not a defect.** |
| **Cut** | Detached, and the project docs already carry it. | Delete. |
| **Relocate** | Detached, but the docs do *not* carry it yet. | Add it to the appropriate doc **first**, then delete inline. Never delete outright. |
| **Negative space** | Documents a deliberate *absence* — why something is NOT here, NOT set, NOT used. | **Keep.** There is no code to rediscover this from. Compress prose, never content. |

**Relocate is the narrow case, not the default.** It applies only when a comment
is *already* detached. Anchored content stays inline however long it is. This is
what keeps the pass from being information destruction.

## Sub-Rules

Each of these is a recurring pattern, not a hypothetical:

1. **Cut a comment that restates the identifier below it.**
   `// Turn off telemetry` above `disableTelemetry = true` adds nothing.
   **But keep it if it decodes a magic value** — an enum whose integers are
   opaque, a four-letter platform constant, a regex, a bit mask. Test: does it
   say something the identifier does not?

2. **Keep the constraint, cut the investigation that found it.**
   "X fails because Y, so we do Z" is worth keeping. "We first tried A, then B,
   then discovered Y" is archaeology — it belongs in the commit message or issue,
   not in the file. Ask: does a future editor need this to avoid breaking it, or
   is it a story about the past?

3. **When N files restate one fact, keep the copy at the decision point.**
   Find the file where someone would actually be *making* that decision and keep
   it there; delete the rest. Usually the entry point or the definition site, not
   the consumers.

4. **Never touch negative-space warnings.** "Do not add X here because Y",
   "deliberately absent", "this looks redundant but is not". These are the single
   highest-value comments in any codebase and the easiest to mistake for noise —
   they describe something not present, so nothing in the code corroborates them.

5. **A cross-reference is only valid if the target already says it.** Before
   keeping or writing "see X", open X and confirm. Never write a pointer to
   content a *later* change is supposed to create.

6. **Duplication across a reciprocal pair can be legitimate.** If two lists,
   flags, or files must be edited in tandem, a short note at *each* edit site is
   correct — whichever one you open, the constraint is there.

7. **A comment justifying something dangerous earns its duplication.** A broad
   permission grant, a disabled safety check, a security-relevant exception:
   keep the rationale on the line even if a doc also states it. The person
   auditing that line should not have to go find the doc.

## Workflow

### Phase 1 — Scope and baseline

Establish what you are reviewing and how you will prove you changed nothing else.

- **Standalone, whole codebase:** enumerate files and comment counts. If the
  total is large, **batch it** (see Batching below) — do not sweep everything in
  one pass.
- **Diff-scoped** (invoked by `code-hygiene`, or reviewing a PR): consider only
  comments on lines added or modified in the diff. Never touch pre-existing
  comments in this mode.

Read the project's own convention docs (`CLAUDE.md`, `CONTRIBUTING.md`,
`CONVENTIONS.md`, `STYLE.md`, `docs/`). You need to know what they already carry
before you can call anything a duplicate. **Do not delete a detached comment
without first confirming the doc actually covers it** — grep for it and read the
passage; do not assume from the section title.

### Phase 2 — Classify

Walk each comment and assign a bucket. Record file:line, the bucket, and a
one-line reason. Do not edit yet — classifying first keeps the standard
consistent across the batch.

### Phase 3 — Apply

Make the edits. Comments only.

> **HARD RULE — zero behavior change.** This pass never edits code. If a comment
> reveals a real bug, dead setting, or wrong logic, **record it as a finding and
> leave the code alone.** Folding a fix into a large comment diff buries it and
> makes the change unreviewable.

### Phase 4 — Verify nothing but comments moved

Prove it mechanically rather than by inspection.

**Primary check — line-level diff audit (works everywhere).** Confirm every
changed line is a comment or blank. For lines carrying a *trailing* comment,
strip the comment from both sides and confirm the remaining code is
byte-identical. Any genuinely changed line of code is a bug in the pass.

```bash
git diff <base>..HEAD -U0 -- '<globs>' | awk '
/^(\+\+\+|---|@@|diff |index |new file|deleted file)/ { next }
/^[+-]/ { line = substr($0,2); gsub(/^[ \t]+/,"",line)
          if (line == "" || line ~ /^<comment-prefix>/) ok++
          else { bad++; print "NON-COMMENT: " $0 } }
END { print "comment/blank: " ok+0 "  code: " bad+0 }'
```

**Secondary — comment-stripped tree diff.** Strip comments from the before and
after trees with the language's own tooling and compare; the result must be
empty. Stronger than the line audit but needs a reliable stripper.

> **Do not rely on build-artifact identity unless you have confirmed the build
> does not copy source files.** It is tempting to assume "comments are stripped
> at parse time, so the artifact hash cannot move" — that is true of the
> *language* and false of many *build systems*. Nix flakes copy the whole source
> tree and resolve in-repo path literals against it, so any byte change anywhere
> rehashes every artifact referencing one; Docker `COPY`, Go `embed`, and
> source-hashing bundlers behave the same way. If artifact hashes move, that is
> not proof the pass changed behavior — fall back to the line audit.

**Verify your comparison tool actually compares.** Confirm it reports a
difference on two files you know differ before trusting a "no difference"
result. Shell aliases, wrappers, and rewrite hooks can silently replace `diff`
with something that does not do what you expect.

Whatever check you use, **say which one you ran** in the report — and never
describe a check you did not actually run.

### Phase 5 — Report

```markdown
## Comment Review

**Scope:** <files / diff> — <N> → <M> comment lines
**Verification:** <which check, and its result>

### Cut (detached — docs already carry it)
- `path/file:12-20` — restated the module layout; `CONTRIBUTING.md:88` has it

### Relocated
- `path/file:5-9` — moved to `CONVENTIONS.md` under "Error handling", then removed

### Kept deliberately
- `path/other:40-52` — long but anchored: explains the retry backoff constant
- `path/third:8` — negative space: "do not add X here"

### ⚠️ Findings (code issues — NOT changed)
- `path/file:81` — comment described a different setting than the one below it;
  the setting itself appears to be dead config
```

## Batching Large Passes

For a whole-codebase pass, work in batches with a review stop between each.

- **Batch by directory or architectural layer**, not by file count.
- **Start with the layer whose comments describe the architecture** (config,
  roles, module wiring, DI setup). That is where detached comments concentrate,
  so it surfaces the most disagreement per line reviewed.
- **Stop after the first batch and get the calls reviewed** before continuing.
  Applying an uncalibrated standard to the whole tree is the main failure mode.
- **Run the line audit against the pre-pass base commit each batch**, not against
  the previous batch — it catches drift an intermediate batch would otherwise
  mask, and costs nothing extra.
- If the whole pass is one logical change, batches can be **review units rather
  than commits** (amend into one commit). If so: verify and review *before*
  folding each batch in, since an amend leaves no per-batch revert.

## Expect to Find Wrong Comments

A comment pass is worth running partly because it is the only process that reads
prose against the code it describes. Neither compilers nor tests nor linters
check whether a comment is *true*.

Comments that name a specific option, file, host, version, or value are the ones
most likely to have drifted — verify each such claim against the code rather than
trusting it. Report every one as a finding (per the hard rule in Phase 3); a
wrong comment is often the visible symptom of dead or misconfigured code.

## Rules

- **Never change behavior.** Comments only. Findings get reported, not fixed.
- **Never delete detached content the docs do not already carry** — relocate it.
- **Never trim an anchored explanation just because it is long.**
- **Never touch negative-space warnings.**
- **Verify cross-references before keeping or writing them.**
- **In diff-scoped mode, never touch pre-existing comments.**
- **State the verification method used** — never imply a check you did not run.
