# Instruction-document rubric — the classes that need a reader

`doc-coherence.sh` carries the classes a grep can decide. These are the rest: real,
recurring, and **not mechanically detectable**. They come from a manual audit of this
harness's own instruction documents that found 37 verified instances across 14 classes;
what follows is that audit reduced to a rubric, so the same pass can be repeated without
redoing the discovery.

Use it as a reading pass over the documents `doc-coherence.sh` reported on — the repo's
`CLAUDE.md`, the deployed global one, and anything the global `@`-imports. Read them
**against each other**, not one at a time: two of the classes below only exist in the pair.

**Report, never rewrite.** A check that edits instruction documents is a check that can
quietly rewrite its own rules. Findings go in the report with a proposed wording; the
edit is the user's.

## How to weight what you find

`doc-coherence.sh` emits a `doc-priority` line when some sections of a document carry a
"hard requirements, not suggestions" banner and others do not. **That line is a weight on
everything here, not a finding of its own.** When the banner does not cover every section,
it cannot arbitrate a conflict between a labelled rule and an unlabelled one — which is
exactly the arbitration a reader attempts, and it resolves toward the labelled side
regardless of which rule is actually correct. A Class 1 conflict where only one side is
bannered is therefore worse than one where neither is.

## The classes

### 1 — competing thresholds on the same event
Two rules govern one event and set different bars. Neither is narrower, neither carves an
exception, and both are satisfiable in isolation — so there are two defensible readings and
nothing adjudicates. This is the most common class and the easiest to miss, because each
rule is locally correct.

The mechanism is almost always the same: **a fact stated correctly for the subset the
author was looking at, then restated as universal from a different vantage.** Look for a
claim quantified over "every" or "all" and check it against the document's own exceptions
elsewhere. Opposed *speech acts* on one event are the other shape — one rule obliging you
to ask, another obliging silence until asked.

### 3 — adjacent sentences that undo each other
The unit is not the bullet, it is **adjacent sentences in one section**, each true of a
different layer or moment, never reconciled. Distinguish this from Class 1: here the
sentences are about the same subject and cannot both be true, rather than setting two bars.

Two tells worth searching for. A **present-tense generalization followed by a specific
contradiction** ("everything under X is a symlink" … "X must be a real directory") — and
the harm is not cosmetic, because believing the first makes a known broken state read as
correct. And a **rule stated with its reason, then restated without it** — the qualifier
that made it correct is dropped on the second telling, and the second telling is the one a
reader hits first.

### 8 — an absolute whose guarantee the same document voids earlier
A rule presented as a hard boundary, where the same document elsewhere documents the
conditions under which it does not hold. Often literally true as written and still
misleading, because it is the reader's summary of the trust model and it omits the
exceptions. Check every "no X can bypass this" and "always" against the document's own
failure-mode sections.

### 12 — an exception added to one rule of a pair
Two rules cover the same obligation — one to *do* the thing, one to *report* it. An
exception gets added to the do-rule and not to the report-rule, so there is no authorized
way to close out the excepted case. The overlap itself is fine; the asymmetry is the
defect. Look for a documented exemption and then ask what the reporting rule says about
the exempted case.

### 13 — rationale naming an entity the document elsewhere excludes
The constraint is right and its stated test is the wrong subject — the named example does
not actually exercise it. Costly because a reader auditing against the rationale tests the
wrong property. Check each "because <entity> needs …" against what the document says
<entity> actually is.

### 11 — dangling cross-reference
"Refer to X for Y" where X contains no Y. **Cut from the script**: word-level matching
passes it, because the individual words of a topic all occur somewhere in a long document,
and the target name may ambiguously refer to more than one file. Cheap for a reader,
unreachable for a grep. Check each pointer by actually looking for the promised content,
and note when the target's name is ambiguous in context — that ambiguity is part of the
finding.

### 4e — the referent exists, the claimed behavior does not
Right name, right file, right registration, **false verb**. Invisible to every existence
check, which is why `doc-coherence.sh`'s `doc-referent` passing says nothing about it. Also
cut from the script: the only mechanical proxy is grepping the named script for a keyword
from the claim, which is too imprecise to report.

Read it directly instead: when a sentence names a script, hook, or command and asserts what
it does, open the thing and confirm the verb. The high-yield case is a claim about a hook or
a lifecycle event, because nobody re-reads those after writing them.

Note the shape it shares with the class below: both are claims about behavior, and behavior
is what text cannot check.

### 6 — stale justification: the rule survives, its stated mechanism is provably false
The rule's advice is still right and its cited history is real, but the *reason* it gives is
false against the current config. This is the highest-value class in the whole taxonomy for
one specific reason: **when the same document also instructs the reader to verify claims
against that config, obeying one rule discredits the other.** A document that trains its
reader to distrust it is a worse failure than a stale path.

Tractable only where the justification names a config the reader can open — sandbox scope,
allow/deny lists, a documented default. Check those; do not attempt it generally.

### X — the two documents contradicting each other
Read the pair together. The instances are thin but real, and most apparent overlap is
genuine layering rather than drift — so the bar is that a session following one document
attempts something the other categorically bans, or omits a default the other requires.

The sharpest shape: **document B states a required step that document A prohibits
absolutely**, especially when B states it correctly elsewhere in its own text. Check every
imperative in the project document against the global document's prohibitions, and check
every command recipe against the global document's stated defaults.

Cosmetic overlaps are worth naming as cosmetic rather than silently dropping, so the next
pass does not re-derive them.

## Two classes that are not yours to decide

**Conflict with the harness's own instructions.** Where the harness's built-in guidance and
a document set different bars for the same judgment, only the *silent* case is a defect —
if the document states why it overrides the default, that is adjudication, not conflict.
Deciding this needs the harness's own instruction text as an input, which nothing here has.
**Record the class as uncovered; do not fake it.** A guessed answer is worse than the
stated gap.

**Stated-but-unenforced.** A rule whose subject is Claude's own procedure that leaves no
artifact when followed — compliance and violation are indistinguishable in the record.
`doc-coherence.sh`'s `doc-unenforced` line flags candidates; that is the whole legitimate
contribution from text. **Hand the list to `skill-reviewer`**, which owns behavioral
evidence, and do not rule on it here.

## One thing that was checked and found clean

**Dated empirical claims going stale.** Sought specifically across all three documents:
every `Verified <date>` claim cross-checked still held. Do not build a check for this, and
do not report its absence as a gap — it was measured, not skipped.
