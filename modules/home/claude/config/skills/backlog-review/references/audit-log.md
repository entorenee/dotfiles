# The audit log, and the ledger behind it

Loaded by `backlog-review` in phase 5. **Written only if an execution pass ran.** A research run
produces the report alone and has nothing to log.

## The run ledger

A machine-shaped scratch file, appended to **as each operation lands** — never reconstructed
afterwards from memory or from a plan of what was going to happen.

```
$ARTIFACTS/<area>/.<slug>-ledger.md
```

One line per operation: timestamp · ticket ID · title · operation · evidence reference ·
confidence band · outcome · recovery deadline where applicable.

**The ledger is never shipped.** It is the audit log's source, and the audit log is the document
people read. Writing the report from the ledger is the one way to get this wrong.

## Reconciliation — measured, not asserted

The failure this exists to prevent: a ledger that closes with `POST tasks=14 completed=5` and a
row of `DELTA_CHECK … OK` lines, where none of those numbers was ever read back from the tracker.
Such a ledger is arithmetic performed on its own claims. **It can be perfectly self-consistent and
entirely wrong.**

So:

1. **Read the tracker's counters before the pass.** Record them.
2. **Read them again after.** Record those too.
3. Reconcile measured-post against measured-pre, line by line, with a ✓ per line and the residual
   stated.
4. **Re-query the operations themselves.** Querying everything completed today should return
   exactly the tickets you closed — no extras, none missing.
5. **Spot-check deletions on the highest-risk cases**, not a random sample. Adjacent IDs and
   anything whose parent was also touched.

If a recorded operation has no corresponding change in the tracker, that is the finding. Report it.

## Shape

```
# <Project> — what changed and why
**<date>** · [<project link>]

<N held → M now. "the record of every change and the evidence behind it, so anyone can
 check the reasoning without re-doing the work">

| | |                               ← headless ledger table
| **Closed** | N — <basis> |
| **Deleted** | N, plus K removed as subtasks of deleted parents |
| **Created** | N, replacing M |
| **Net** | N → M open (x top-level, y subtasks) |

**Nothing was closed or deleted on a hunch.** <the warrant: every item was High or Medium,
 and the user approved the enumerated list>
**Everything is reversible.** <closed items reopen; deleted items recoverable until DATE>

## Closed — N
### <sub-reason group>          | Ticket | Evidence |

## Deleted — N, plus K by cascade
### The premise no longer exists | Ticket | Why |
### Superseded                   | Ticket | Replaced by |

## Deliberately left alone       | Item | Why |

## Verification
   **Operations:** <re-query, expect an exact count>
   **Deletions:** <highest-risk spot-check, named>
   **Arithmetic:** <measured pre vs measured post, ✓ per line, residual stated>

## Where the analysis was wrong
   | Initial conclusion | Corrected to | Caught by |
   <plus any near-miss worth recording>

## Recovery reference
   <why IDs live here: the one thing they are needed for is undoing something>
   **Deleted directly (N)** · **Removed by cascade (K)** ·
   **Closed (N)** — reopen rather than recover · **Created (N)**
```

## Where the analysis was wrong — required

Not optional, and not omitted when it would be empty — an empty section says the adversarial pass
found nothing, which is itself a claim worth making.

Any pass over a real backlog reverses some of its own early calls. A template without this section
invites quietly dropping the reversals, and the reversals are the most useful thing in the
document: they are the reason the next reviewer will not re-walk the same dead end.

Record near-misses too. One search prevented deleting a live product question, on the strength of
a project that turned out to be an unrelated form — that sentence is worth more to the next
reader than any of the successful calls.
