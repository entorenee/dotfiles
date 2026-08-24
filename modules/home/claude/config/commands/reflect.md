---
description: Mine this session's friction points and store the durable ones to memory before the session closes or compacts.
argument-hint: [optional focus — e.g. "just tooling gotchas" or "skip preferences"]
---

# /reflect

Harvest what this session learned the hard way, and persist only the parts a future session cannot re-derive. Run this before compacting, before ending a long session, or at a commit boundary after a messy investigation.

The goal is an actively useful memory set, not a complete one. Bias toward few, high-signal entries.

## 1. Find the friction

Re-read the session and list every point that cost something. Friction is the signal — smooth work teaches nothing worth storing.

- **User corrections.** A wrong claim, a wrong assumption about repo state, a preference about how output should look. Highest-value; almost always worth keeping.
- **Wasted tool calls.** A command that needed a different form, a path that read as empty because it was blocked, a binary that was not what it appeared to be. Record the *misleading symptom*, not just the fix — the symptom is what a future session encounters first.
- **Revised conclusions.** Any hypothesis stated confidently and later falsified. Record what falsified it.
- **Repeated lookups.** Anything looked up twice, or re-derived because it was not written down.
- **Surprises.** Behavior that contradicted a reasonable expectation.

If the session had no friction, say so and stop. Do not manufacture entries.

## 2. Filter — verify, do not judge

Drop anything that fails these. For the first two, **run the check; do not rely on recall of what the files contain.**

- **Already recorded.** Grep `CLAUDE.md`, the relevant module or code comments, and the plan doc if one exists. Duplicating creates two copies that drift.
- **Already in memory.** Read `MEMORY.md` and open every file that looks adjacent. Prefer updating an existing file over adding a near-duplicate. Delete one this session proved wrong.
- **Conversation-scoped.** True only for this task, branch, or file. A fact that expires when the work merges is not memory.
- **Re-derivable in one command.** If `git log` or a single grep answers it, skip it.

## 3. Ask about the uncertain ones

Do not resolve borderline cases alone. Batch every uncertain candidate into **one** round of questions and ask. Ask when:

- It is unclear whether something is a durable preference or a one-off reaction to this task
- A candidate substantially overlaps an existing memory and the merge is not obvious
- It might belong in `CLAUDE.md` instead (see below)
- It is a claim about the user's intent rather than something observed

A candidate you cannot justify in one sentence is a candidate to ask about, not to write.

## 4. Route by kind

| Kind | Destination |
|---|---|
| Repo patterns, tool conventions, CLI gotchas another machine would need | `CLAUDE.md` — **propose the edit and ask first**, it is committed |
| User preferences, feedback on how to work, harness or machine quirks | memory file |
| An obstacle that cost something and prompted an adaptation — about the tooling or the process, not a fact to recall | the friction log, via `friction-capture` |
| Neither durable nor general | drop it |

Memory and the friction log are not alternatives: memory changes how a future session *works*, the friction log records what the effort *cost* and what changed in response. One event can warrant both. Route to the log only when there is a cost and an adaptation to state — otherwise it is a memory entry.

Memory lives in the per-project directory keyed by cwd. In a git worktree, write project- and repo-wide entries to the **default-branch** worktree's memory dir so they survive the branch; keep only branch-scoped notes local. (The dotfiles repo does not use worktrees, so this does not apply there.)

**Promotion.** If a memory keeps getting exercised across three or more sessions, it has outgrown memory. Propose moving it — a *fact* to `CLAUDE.md`, a *repeatable procedure* to a skill — and delete the memory once promoted, rather than keeping both.

## 5. Budget

Target roughly **15 memory files**. This is a budget, not a hard cap: never drop something useful just to stay under it.

When at or over the target, rank existing entries by recent usefulness before adding more:

- Grep the recent transcripts in the project directory (`*.jsonl`) for each memory's subject terms. **Recalled memories are injected into every transcript inside `<system-reminder>` blocks, so raw hit counts overcount everything** — only count occurrences in actual user and assistant turns.
- Check file mtime, and whether the memory has been updated since it was written.
- Verify the memory's referents still exist. One naming a file, flag, or command that is gone is stale regardless of how often its topic comes up.

Then **propose** the weakest entries for removal with the evidence for each, and ask. Never delete unprompted. If everything genuinely earns its place, say so and ask whether to raise the target rather than dropping something.

## 6. Write

One fact per file, kebab-case name, and this frontmatter:

```markdown
---
name: <slug>
description: <one line — this is what future-you reads to decide relevance>
metadata:
  type: user | feedback | project | reference
---
```

For `feedback` and `project`, follow the fact with **Why:** and **How to apply:** lines. Link related entries with `[[slug]]` — liberally, including to files that do not exist yet.

Keep entries short. State the constraint and how to act on it; leave out the investigation narrative that produced it. Then add one line per new file to `MEMORY.md` (`- [Title](file.md) — hook`). Never put memory content in `MEMORY.md` itself.

## 7. Report

List what was written, updated, proposed for removal, and deliberately skipped — with the reason for each skip, since "already in `CLAUDE.md`" is itself useful confirmation. Flag anything routed to `CLAUDE.md` or proposed for deletion as still needing approval.

Do not run `git add` or `git commit`.
