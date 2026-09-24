# Classification — lenses, evidence, confidence

Loaded by `backlog-review` in phases 1–3.

## The two lenses

The method is identical; the vocabulary and the notion of grounding differ.

| | **Feature lens** | **Debt lens** |
|---|---|---|
| Subject | One active feature or epic | A long-lived backlog |
| Question | Does each ticket's stated status match what shipped? | Which items are still real? |
| Readings | `shipped` · `in-flight` · `not-started` · `superseded-by` · `missing` | `done` · `premise-gone` · `superseded-by` · `still-real` · `needs-owner` |
| Primary grounding | Merged PRs, `file:line`, release/version | Absence-greps, repo archive status, manifest counts, telemetry |
| Typical surprise | Tickets closed while the code path is still unwritten | Milestones whose year has ended but whose subtasks are live |

`missing` is feature-lens only and matters most: work the code implies but no ticket covers.

## Census

List views hide subtasks, so the visible count is not the open surface. A real example: a project
showing **49** items held **129** — the other 80 were one level down.

Report, before reading any individual ticket:

| Measure | Why it matters |
|---|---|
| Total · completed · incomplete | Reconciles against the tracker's own counters later |
| **Incomplete: top-level vs subtask** | The gap is the hidden surface |
| **Open subtasks under a completed parent** | Live work behind a green milestone — the most expensive structural defect |
| Created per year | Locates the aged long tail |
| Has assignee · has due date | Ownership, usually near zero on a stale backlog |
| Blank / near-blank tickets | Data-entry artifacts |

Fix or flag structural findings first. They change what individual tickets mean — three "stale"
tickets under a closed milestone are not stale, they are invisible.

## Evidence classes

Strongest first. Every claim names one, or the ticket is Unverifiable.

| Class | Looks like |
|---|---|
| Code location | `CustomMRTTable.tsx:331` sets `rowCount` — the feature exists |
| Merged PR / release | the work landed in `v4.2.0` |
| Repo state | repo archived 2026-06-16; last commit 2026-04-13 |
| Telemetry | `SignupSubmit` failures 12 → 410/day since v4.2.0 **plus the exact query** |
| Manifest count | `package.json` has 169 dependencies and 0 devDependencies |
| Absence-grep | zero references to `Segment` anywhere — **and** name the successor |
| Name-and-purpose match | `uberReconciliation.ts` matches the ticket by name, not line-by-line |
| Infrastructure lookup | DNS shows the origin is still the platform we believed we left |

**An absence-grep is only evidence if you say what you searched.** "No code matches" over a
seven-file slice of a larger system is not the same claim as over the monorepo.

## Confidence

Read the band off the evidence class. Do not assign it by how convincing the claim feels — two
runs over the same ticket should land on the same band.

| Band | Warrant |
|---|---|
| **High** | A direct artifact confirms or contradicts the premise: code location, merged PR, repo archived with date, telemetry value with its query |
| **Medium** | One inferential step removed: absence-grep with the successor named, manifest count, name-and-purpose match |
| **Low** | Age, inactivity, emptiness, or surrounding context only — no artifact |
| **Unverifiable** | The check that would settle it cannot run here: no repo, no telemetry, dead links, decommissioned tooling |

### The routing rule

**Low and Unverifiable can never carry a delete or close reading.** They go to the report as
questions, with the check that would settle them named.

This is the rule the whole skill turns on. Three worked failures it prevents:

- A ticket called obsolete because "the infrastructure changed" was **live** — 14 events in 90
  days. Low banded as done.
- Eight tickets whose error-tracker links had died were read as harmless. Measured later at
  **3,156 s of server time per week**. Unverifiable banded as harmless.
- Three subtasks under a closed milestone, empty and untouched, were recommended for deletion by
  a baseline agent that had *itself* written "neither fact says the work was done."

### Reporting it

Confidence is a column, not a footnote — in the ranked duplicates table and in the dispositions
table. State the banding rule once in the report so a reader can audit the call rather than
trust it.

## Duplicates

Record as **supersession**, not as "duplicate": name which ticket survives and where the content
went. The recurring verb is *folded into*.

Two requirements per claim:

1. **Name the survivor.** A duplicate pair with no designated survivor is two tickets nobody will
   act on.
2. **One confirming check beyond the titles.** Similar titles routinely describe different
   surfaces — a public application form and an internal onboarding survey both read as "shorten
   the form", and merging them silently drops real work.

When the survivor's own note claims scope it does not have, the code wins. A ticket asserting it
"covers SSR + prefetch for the whole area" while the component is still client-rendered has not
absorbed the other ticket; it has only claimed to.
