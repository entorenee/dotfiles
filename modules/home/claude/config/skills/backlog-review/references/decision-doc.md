# The report

Loaded by `backlog-review` in phase 4. This is the skill's deliverable, and on a research run it
is the only document produced.

**Author it from the classification, never from a run ledger.** The ledger is an input to the
audit log alone. A report derived from an operations log inherits the log's shape no matter how
it is edited afterwards.

## What it is

A document that tells a reader which tickets the evidence settles, which it does not, and what
question would settle the rest. It reports **readings**, not work orders. The column heading is
`Reading`, not _Recommended action_ — the difference is whether the reader is being informed or
instructed.

## Shape

```
# <Project> — <what the review found>
**<date>** · [<project link>]

<one paragraph: the census result and the headline. If an execution pass later runs,
 name the companion document here.>

<one sentence: what this document is — the open decisions and the ranked duplicates.>

## First: <escalation, if any — outside the numbering>
   <why it is here rather than in the backlog: it has a user-facing consequence>
   <evidence: what exists, what does not, what was searched>
   > **<The question, bolded>**
   > **Yes** → <consequence>. **No** → <consequence, including re-routing elsewhere>.

## Likely duplicates — ranked
| # | Ticket | Superseded by | Confidence | What settles it |
   <High → Medium only. Low and Unverifiable are questions below, not duplicates.>

## Dispositions
| Ticket | Reading | Confidence | Evidence |
   <Reading uses the lens vocabulary. Evidence names a class, or the row is Unverifiable.>

## Open questions
## 1..N. <Milestone or theme> — <k> items
   **Untouched since <date> · <movement stat> · <owner state>**
   <why it exists; what changed underneath it, with cited artifacts>
   > **<The question>**
   **Suggested:** <a pre-committed recommendation>
   **Who answers, and what it costs:** <named role · "one conversation" / "about an hour">

## Context for the rest
   <the count that needs no discussion, so the reader knows the questions are the whole ask>
   | Item | Created |

## Coverage
   <which sources were queried; which roles had no source; every check that could not run>
```

## Rules

**Confidence banding is stated once, above the tables.** A reader who cannot see how a band was
assigned has to trust it, which defeats the point of reporting it.

**Every question names who answers it and what answering costs.** "Whoever owns the deploy can
answer in a minute" converts a stalled item into a scheduled one. A question with no owner is a
question that will still be open at the next review.

**Where there is no signal, say so as a finding.** "This is the one question here with no useful
engineering signal — it needs whoever owns program steps" is more useful than a paragraph of
hedging, and far more useful than a guess.

**Escalations go first and outside the numbering.** Anything with a possible user-facing
consequence is not really a backlog question, and burying it at position four in a list of five
treats it as though it were.

**Check the prose length against the Phase 0 budget** with `wc -w` before handing back — and
measure the prose, not the dispositions table. That table carries one evidence cell per ticket and
grows with the backlog; trimming it to hit a word count deletes the evidence the report exists to
carry. Three verification runs each overran a flat budget, each flagged the overrun, and each was
right to keep the column. If the prose is over, cut the prose.

## How it ends

With the findings. The high-confidence duplicates and the verifiably-settled tickets are stated
as facts about the backlog.

**No offer to execute. No "want me to clean these up?". No pasteable command block.** Every
baseline run of this workflow volunteered one unprompted — one closed with _"the destructive half
is one command away whenever you say go"_, another supplied a ready `delete` command. The user
asked for a review; a review is a complete answer.
