---
name: friction-briefing
description: Use when the AI-tooling effort has to be accounted for to someone who has not been in the sessions — asked how it is going, what it has cost, what it has bought, whether it is working, or when preparing to report upward. Renders the private friction log into a layered briefing: obstacles, adaptations, and what is still open, with business framing rather than tooling internals. Not for reviewing whether one skill works (use skill-reviewer) and not for the periodic system sweep (use system-review).
---

# Friction Briefing

## Overview

A rendering of the friction log, not an addition to it. **The private repo is what
lets the log stay detailed** — confidentiality is a property of where the log is
stored, not of how it is rendered. So this renders **in full by default**.

Sanitization is offered, never assumed. It costs clarity: an obstacle stated as a
class rather than an instance is harder for a technical reader to evaluate, and the
default audience — the user and their CTO — already has access to the specifics.
Reach for it only when the briefing leaves that circle.

Audience is the user and their CTO. The user is a legitimate reader, not a
bystander — a human-readable friction consolidation is the thing generic insight
tooling does not provide, because its advice is not grounded in what actually
happened here.

## When to Use

- Asked how the tooling effort is going, or what it has cost and bought
- Preparing to report upward, or to someone who has not been in the sessions
- A reviewer needs the obstacles and adaptations without reading 16 entries

## When NOT to Use

- Whether one skill is working → `skill-reviewer`
- The periodic sweep of what is due → `system-review`
- Capturing *new* friction → `friction-capture`. This skill never creates an entry. If
  rendering surfaces uncaptured friction, say so and invoke that. It may **correct** an
  existing entry, but only from a Step 4 drill-down that showed the entry itself to be
  wrong — never as a tidy-up pass.

## Hard rules

**Sanitization is a per-run choice; everything else here is unconditional.** The rules
below concern accuracy and fairness, not data sensitivity, so they apply in full-detail
mode exactly as they do in sanitized mode. Do not treat "the audience is trusted" as
license to relax any of them.

**Findings attach to documents and code, never to a person's judgment.** This is
F13, and it exists because the log once claimed — in a document intended for the
CTO — that a review call of the user's had been wrong, with no evidence and against
what the cited quote actually showed. The audience makes this the most consequential
rule here: the cost of being wrong is not a retracted finding but a
misrepresentation of a person to their management.

**Do not soften or inflate.** A `won't-fix` is reported as such. An `unverified:`
claim in an entry stays marked unverified in the briefing, or is left out.

**Length: layered, not compressed.** The subject is genuinely complex and the
briefing has to carry *why* the obstacles are hard. Lead with the decision surface so
a reader can stop there; put evidence below it for anyone checking. Do **not** apply
a "just a few paragraphs" instruction — that strips the reasoning this exists to
convey.

## Step 1 — read

```bash
ROOT="${MY_CLAUDE_FRICTION_ROOT:?unset — run 'make rebuild', then start a new session}"
git -C "$ROOT" pull --ff-only 2>&1 | tail -1
ls "$ROOT/entries/" "$ROOT/briefings/"
```

Read every entry. Read the most recent briefing too — the "what changed" section is a
diff against it, and repeating an unchanged obstacle as though it were news is how a
briefing loses credibility.

Then **ask which mode**, before rendering anything — a rendered briefing cannot be
un-sanitized, and mixing modes within one document is worse than either:

| Mode | Use | Output |
|---|---|---|
| **Full detail** (default) | The user, the CTO, technical review — anyone who already has access to the log | `briefings/YYYY-MM-DD.md` |
| **Sanitized by class** | The briefing is leaving that circle | `briefings/YYYY-MM-DD-sanitized.md` |

Distinct filenames are deliberate: the two are different artifacts with different
audiences, and one should never be mistaken for the other when handing a file over.

**Full-detail mode carries the specifics through verbatim.** This needs stating as
plainly as the sanitized rules below, because the two branches are not symmetric in
effort: generalising is an active habit and reproducing an identifier is not, so a
render given rules for only one branch drifts toward that branch. The drift is partial
and quiet — some kinds of specific survive while others vanish, and the result still
reads as a complete briefing. So in this mode, name the customer, the internal system,
the business rule, the table, and the column. If an entry names it, the briefing names
it — a specific is not softened, abbreviated, or replaced by its class here. Dropping
one is the behavior this default exists to prevent, not a courtesy.

**Sanitized mode, when chosen:** render what *kind* of thing went wrong and drop the
instance — *"a join key whose semantics were absent from the schema"*, never the key,
the table, the customer, or the internal system. If an obstacle cannot be stated
without its specifics, name the class and say the detail is in the log. Paths, files,
commits, and skill names in the dotfiles repo stay in full; it is public. Watch the
other failure direction: an obstacle sanitized until it conveys nothing is worse than
omitting it, because it occupies space while informing no one.

## Step 2 — group and rank

Group by **theme**, never by F-number. Numbers are creation order and carry no
meaning to the reader. Several entries usually describe one obstacle from different
angles — say so and cite them together, rather than listing near-duplicates.

Rank by consequence: what is blocking work, then what is costing time, then what is
merely recorded. A `fixed` entry earns a line under what changed, not a section.

Roll the statuses up into a count, so the shape of the effort is visible without
reading the parts.

## Step 3 — render

Write to the filename the chosen mode dictates (`YYYY-MM-DD.md` or
`YYYY-MM-DD-sanitized.md`), and state the mode in the document itself so a reader
knows whether they are holding the full picture:

```markdown
# Friction briefing — YYYY-MM-DD

**Detail:** full — specifics included, for readers with log access.
(Sanitized renders say so instead, and name what was generalised.)

## Where this stands
Three to five sentences. What the effort is, what it has cost, what it has bought.
Someone who reads only this should not be misled.

## Decision surface
What needs a decision or awareness now, ranked by consequence. One row each:
obstacle, what it costs, the adaptation, status.

## What changed since <date of previous briefing>
Only genuine movement. If nothing moved, say that.

## Still open
Ranked, each with what would close it.

## Evidence
Per-item detail with citations. The reader may stop before this section.
```

Dated files accumulate here deliberately, and this does not violate F8: each briefing
is a bounded snapshot of what was reported on a date, not a document that grows and
must be read in full to be discounted. The current view is always the newest file.

Print the absolute path. **The briefing is emitted before any drill-down** — that
ordering is the design, not a formality, and Step 4 explains why.

## Step 4 — stop, then drill down

**This is a real halt.** Treat it the way a plan phase treats a `MANUAL REVIEW
CHECKPOINT`: emit the document, stop, and let the user read it. Then ask which points
they want pressed on.

**Detail is produced on demand, never pre-emptively.** Pre-computing the evidence
behind every entry is the context-heavy work this ordering avoids, and avoiding it is
what makes a weekly cadence affordable. Detail is produced *against a document the user
has already read*, for the entries they chose — so do not expand anything nobody asked
about.

For each point the user presses, surface:

- **The evidence behind the claim** — the `file:line`, commit, or command output the
  entry cites, re-read rather than relayed from the entry's summary.
- **The quotation in full.** A quotation trimmed to the supporting clause is the
  mechanism of F13, and the drill-down is precisely where that becomes checkable.
- **Who or what the finding is attributed to.** It must be a document or a line of
  code. If drilling down reveals a finding attributed to a person's judgment, say so
  plainly — that is the failure this step exists to catch, and reporting it is the
  step working.

**The halt is what sends the notification, so nothing needs to be called.** A
`Notification` hook is already registered and fires on an idle prompt. Its body is the
last assistant text block, whitespace-collapsed and truncated to **100 characters** —
so the final line before halting *is* the banner. Lead with the artifact path and the
ask; preamble is spent inside the only 100 characters the user sees.

## Step 5 — refine and reconcile

Fold the drill-down results back in. **Plural files, deliberately:** a drill-down can
show that an *entry* misstates something, not merely that the briefing summarized it
thinly. When it does, correct the entry too — and `friction-capture`'s rule governs
how: **keep the correction visible rather than overwriting**, because the original
error is usually the more useful record.

Then confirm the markdown on disk matches what was concluded, and print the path again.

**Do not run git.** `services.git-sync` commits and pushes both `briefings/` and
`entries/` on its own, unsigned, within a few minutes. There is nothing to hand over.

**The markdown file is the deliverable. There is no export step.** A Google Doc export
was designed for this skill and then scrapped 2026-08-21: the server was never wired, and
handing over a path the user can paste wherever they need it costs them less than the
OAuth client the export would have required. **Do not offer an export, and do not
reintroduce one** — the path is the hand-off.

## Quick reference

| Step | Action |
|---|---|
| 1 | Resolve `$MY_CLAUDE_FRICTION_ROOT`; `pull --ff-only`; read all entries and the last briefing; **ask full detail or sanitized — default full** |
| 2 | Group by theme, rank by consequence, roll up statuses |
| 3 | Write `YYYY-MM-DD.md` (or `-sanitized.md`), state the mode in the document, decision surface first, evidence last; print the path |
| 4 | **Stop.** Let the user read it, then ask what to drill into. Per point: evidence re-read, quotation in full, attribution. Final line before the halt is the notification — path and ask first, 100 chars |
| 5 | Fold results back into the briefing *and* into `entries/` where an entry itself was wrong, correction visible; no git; print the path — the markdown **is** the deliverable, there is no export |
