---
description: Close out a session so a cold session can pick the work up — refresh the plan's status block from live state and point memory at it.
argument-hint:
  [optional — e.g. "skip memory" or the plan path if there are several]
---

# /handoff

The user is stopping for now. Leave the work so that a session with **no memory of this
conversation** can resume from one file. The deliverable is that file, kept current, not a recap
in chat.

`/reflect` is the companion for durable lessons (preferences, gotchas). `/handoff` is about **the
state of this piece of work**. Don't duplicate between them.

## 1. Find the handoff file

- If this session worked from a plan or design doc in `$ARTIFACTS/plans/` (or a path given as the
  argument), that is the file.
- If the work spans sessions but has no doc yet, create
  `$ARTIFACTS/plans/<YYYY-MM-DD>-<topic>.md`.
- If the work finished this session and nothing is pending, say so in one line and stop. No file.

## 2. Collect current truth — run it, don't recall it

- `git log --oneline` and `git status --short` for every repo touched. Note commits the user made,
  and whatever is still uncommitted.
- Re-read every file this session changed. The user often edits between turns; treat their version
  as the intended one.
- Check the live state the next step depends on (generated files, mounted devices, stray outputs).
  Anything unexpected goes in the file as an observation, and is never deleted.

## 3. Write the status block

At the top of the file, under `## Status (as of <date>) — START HERE`, include exactly these parts:

1. **Where it stands:** each phase or chunk as _done (commit hash)_, _in progress (what is
   uncommitted)_ or _not started_. Mark what the user _reported_ separately from what you
   _verified_. Never tick a QA box the user didn't confirm.
2. **Current state:** a few bullets on how the system or code is now. Enough to avoid re-deriving
   it, not a diff.
3. **Before the next step:** an ordered checklist. Include unverified assumptions (by ID, if the
   doc has an assumptions table), files to re-read, and open decisions. Write each decision as
   _decided (date, by whom)_ or _open (current default)_.
4. **Facts from this session:** things learned that are in neither the code, `CLAUDE.md` nor
   memory. Include exact commands that took effort to get right.

Then bring the rest of the doc into line in place. Mark finished phases `DONE, <hash>`, and change
"starting state" wording into history. Don't add a changelog section.

## 4. Point memory at it

Make sure one memory entry links to the handoff file's absolute path. Update the existing entry for
this area rather than adding a new one. Durable lessons go to `/reflect`, not here.

## 5. Report

Give the file's absolute path, the open items for next time in 3–5 bullets, and anything the user
has to do or decide before resuming. Keep it short: they're leaving.

Do not run `git add` or `git commit`.
