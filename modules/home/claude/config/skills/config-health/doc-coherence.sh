#!/usr/bin/env bash
# Instruction-document coherence checks.
#
# Same contract as config-checks.sh: STATUS<TAB>CHECK<TAB>DETAIL, exit 0 always.
#   OK     — verified good, no action
#   FAIL   — provably broken, act on it
#   REVIEW — needs human eyes; the script cannot decide (never assert on these)
#
# Subject: the instruction documents themselves — this repo's CLAUDE.md and the
# deployed global one — read as plain text. This script knows nothing about how
# either file got where it is. That is deliberate: it has to work in any repo,
# which is where it earns its keep, and the deployment mechanism is irrelevant to
# whether a document contradicts itself.
#
# Two modes, and they must not blend. CHECKOUT mode has a repo and no harness
# state; LIVE mode additionally has a rebuilt machine. A checkout-mode check that
# reads ~/.claude fails on every fresh clone and gets disabled within a week, so
# the live-only check announces itself as skipped rather than passing.
#
# Every check here was validated against the instances a manual audit had already
# found, and two candidate checks were CUT because they could not reproduce their
# own known instance — see the "Deliberately not here" list at the bottom.
# Shipping a check that cannot find the defect it was written for is worse than
# not shipping it: it converts an open question into a false all-clear.
#
# What this does NOT cover, stated rather than implied:
#   - Conflicts with the harness's own instructions. Needs the harness prompt as
#     an input, which nothing here has. The class is real; faking it is worse.
#   - Whether a stated rule is actually obeyed. Text cannot see behavior. Check 7
#     flags candidates and hands them to skill-reviewer; it decides nothing.
#   - Whether an mcp__* prefix names a tool that exists on the server. Needs a
#     live authenticated session against a third party.

set -uo pipefail

REPO="${REPO:-$PWD}"
REPO_DOC="${REPO_DOC:-$REPO/CLAUDE.md}"
GLOBAL_DOC="${GLOBAL_DOC:-$HOME/.claude/CLAUDE.md}"
SETTINGS="${SETTINGS:-$HOME/.claude/settings.json}"

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# Documents readable this run: the repo's, the global one, and whatever the
# global @-imports — an imported file is part of the same instruction surface,
# and a contradiction does not care which file it landed in.
DOCS=()
[[ -f "$REPO_DOC" ]] && DOCS+=("$REPO_DOC")
if [[ -f "$GLOBAL_DOC" ]]; then
  DOCS+=("$GLOBAL_DOC")
  while read -r imp; do
    [[ -n "$imp" && -f "$(dirname "$GLOBAL_DOC")/$imp" ]] && DOCS+=("$(dirname "$GLOBAL_DOC")/$imp")
  done < <(grep -hoE '^@[A-Za-z0-9._/-]+' "$GLOBAL_DOC" 2>/dev/null | sed 's/^@//')
fi

LIVE=0
[[ -f "$GLOBAL_DOC" ]] && LIVE=1

# --- Discrimination -----------------------------------------------------------
# Illustrative examples are the dominant false-positive source in every check
# below, and these rules are what let any of them hard-fail at all. Derived from
# a manual pass in which they dropped every placeholder with no false negatives.
PLACEHOLDERS='^(my-feature|bug-name|tool|name|host|hostname|area|branch|repo|pkg|cmd|attr-name|gen|hash|owner|slug|date)$'

is_placeholder() {
  local r="$1"
  [[ "$r" =~ [\<\>] || "$r" == *'{{'* || "$r" == *'...'* || "$r" == *'…'* ]] && return 0
  [[ "$r" =~ $PLACEHOLDERS ]]
}

# Terms a document itself declares abolished, harvested from its own retirement
# sentences. This is shared state between checks 1 and 3, and that sharing is
# the point: a reference to a retired path is not a broken referent — it is
# correct prose about something gone. Without this, check 1 hard-fails on the
# very sentence that documents the removal.
# Normalised so a declaration and a later mention match each other: a retirement
# sentence tends to spell the path out in full (`<repo-root>/docs/local/`) while
# the surviving mention is bare (`docs/local`). Without stripping the angle-bracket
# prefix and the trailing slash, the declaration never suppresses the mention and
# check 1 hard-fails on the very sentence documenting the removal.
retired_terms() {
  { grep -hoE '`[^`]+`[^.]{0,90}(is the retired location|is retired|no longer exists|was removed|has been removed|is obsolete|has been retired)' "$1" 2>/dev/null \
      | grep -oE '^`[^`]+`'
    grep -hiE 'there is no |do not gate on |is the retired location|no longer hardcodes|was retired' "$1" 2>/dev/null \
      | grep -oE '`[^`]+`'
  } 2>/dev/null | tr -d '`' | sed -E 's#^<[^>]*>/?##; s#/$##' | sort -u
}

fence_lines() { awk '/^```/{inf=!inf; next} inf{print NR}' "$1"; }

# A quoted span in these documents holds RETIRED wording, not a live rule. The
# convention this whole effort runs on is to keep a correction visible rather
# than overwrite it — so a document states the old text verbatim, in quotes,
# beside the new one. Any check that matches rule PHRASING then reads the
# preserved correction as a fresh defect, and the only other escape is to stop
# quoting, which pressures the documents to drop their own history to keep a
# checker quiet. Same shape as fence_lines() above: a region the matcher does
# not read.
#
# Double quotes ONLY, and that is a graded decision rather than an oversight.
# `*...*` was proposed alongside them and CUT. Asterisks are EMPHASIS in these
# documents, not quotation, so the span they delimit is usually live text.
# Measured both ways against a fixture holding a live hedge inside emphasis
# ("Pick the host set *as appropriate*"): quotes-only flags it, quotes+asterisks
# reports OK. That is a false negative bought for nothing — neither variant
# differed on the two real documents. A skip that blinds a check is worse than
# the false positive it was written to remove.
#
# Scope is deliberate. Applied to the checks that match rule phrasing
# (doc-unfalsifiable, doc-unenforced's artifact test) and to doc-attribution's
# claim cell. NOT applied to doc-referent or doc-prescription: a path or a
# command named inside a quotation is still a real referent, and still resolves
# or does not.
strip_quoted() {
  awk '{ s=$0; while (match(s, /"[^"]*"/)) s = substr(s, 1, RSTART-1) substr(s, RSTART+RLENGTH); print s }'
}

# Same strip, carrying the original line number so a finding still points at a
# line the reader can open.
strip_quoted_numbered() {
  awk '{ s=$0; while (match(s, /"[^"]*"/)) s = substr(s, 1, RSTART-1) substr(s, RSTART+RLENGTH); printf "%d:%s\n", NR, s }' "$1"
}

# --- Check 1: named referents exist -------------------------------------------
# CHECKOUT mode. A manual sweep of these documents found ZERO broken referents,
# so an empty result here is the expected state: this is regression protection,
# not a backlog, and it should be reported that way.
#
# ANCHORING is what makes this safe, and it is computed at runtime rather than
# hardcoded so the check stays repo-agnostic: a backticked string only counts as
# an in-repo path if its first segment is an actual top-level directory of this
# repo. Without that anchor, "a backticked string containing a slash" sweeps in
# branch-name prefixes (`feat/`, `fix/`), other trees' subdirectories (`agents/`,
# `skills/`), and container directories from unrelated repos — 24 false positives
# against a manually verified zero, on the first attempt at this check.
#
# Hidden top-level directories are excluded from anchoring on purpose. A repo's
# own `.claude/` is not the harness's `~/.claude/`, and documents refer to the
# latter constantly.
#
# Second tier: a path that anchors but whose PARENT directory is also absent is
# almost always another project's tree (a home-manager upstream module path is
# the worked example) and is counted, not failed.
check_referents() {
  local doc broken=0 checked=0 external=0 n ref
  local anchors; anchors=$(find "$REPO" -maxdepth 1 -mindepth 1 -type d -not -name '.*' -exec basename {} \; | sort)
  [[ -z "$anchors" ]] && { emit REVIEW doc-referent "no top-level directories under $REPO — cannot anchor path references. Skipped, not passed."; return; }
  for doc in "${DOCS[@]}"; do
    local fences retired
    fences=$(fence_lines "$doc"); retired=$(retired_terms "$doc")
    while IFS=: read -r n ref; do
      [[ -z "$ref" ]] && continue
      grep -qx "$n" <<<"$fences" && continue
      is_placeholder "$ref" && continue
      grep -qxF "${ref%%/*}" <<<"$anchors" || continue
      grep -qxF "${ref%/}" <<<"$retired" && continue
      checked=$((checked + 1))
      [[ -e "$REPO/$ref" || -e "$REPO/${ref%/}" ]] && continue
      if [[ -d "$REPO/$(dirname "${ref%/}")" ]]; then
        emit FAIL doc-referent "$(basename "$doc"):$n names '$ref' — its parent directory exists in $REPO but the leaf does not. Renamed or moved without editing the prose."
        broken=$((broken + 1))
      else
        external=$((external + 1))
      fi
    done < <(grep -noE '`[A-Za-z0-9_.][A-Za-z0-9_./-]*/[A-Za-z0-9_./-]*`' "$doc" \
             | sed 's/`//g' | grep -vE ':(https?|~)' )
  done
  [[ $external -gt 0 ]] && emit REVIEW doc-referent "$external anchored path(s) resolve nowhere in $REPO and their parent directory is absent too — usually a reference to another project's tree, which is legitimate. Spot-check if a rename is suspected."
  [[ $broken -eq 0 ]] && emit OK doc-referent "$checked anchored in-repo path reference(s) across ${#DOCS[@]} document(s) resolve — regression protection, currently holding"
}

# --- Check 2: attribution drift -----------------------------------------------
# CHECKOUT mode, and the highest-yield check here. Reorganizations relocate an
# option without anyone editing the table that describes it, so a row keeps
# crediting a file that no longer holds what it claims. Invisible to check 1:
# the file exists, the claim about it does not.
#
# The discriminator that makes this precise rather than noisy: a word only counts
# if it is ASSIGNED somewhere in the tree — it appears on a line with an `=` in
# some .nix file, as an option name does — but not in the credited file. Plain
# substring presence is far too weak; it passed "options", "roles" and "above" as
# option names. The assignment form is what separates `taps = [ … ]` from the word
# "options" appearing in prose inside a .nix comment.
check_attribution() {
  local doc rows=0 flagged=0
  local nixfiles; nixfiles=$(find "$REPO" -name '*.nix' -not -path '*/.git/*' 2>/dev/null)
  # The one check here whose subject matter is Nix-shaped, because a doc table
  # crediting a file with an option is a config-repo idiom. It degrades to a
  # stated skip elsewhere rather than pretending to have run.
  [[ -z "$nixfiles" ]] && { emit REVIEW doc-attribution "no .nix files under $REPO — this is the one check keyed to a Nix config tree, and there is nothing here to compare a doc table against. Skipped, not passed; the rest of this arm is language-agnostic."; return; }
  for doc in "${DOCS[@]}"; do
    while IFS=$'\t' read -r n file claim; do
      [[ -z "$file" ]] && continue
      is_placeholder "$file" && continue
      [[ -f "$REPO/$file" ]] || continue   # a nonexistent file is check 1's finding
      rows=$((rows + 1))
      # A row that records what it used to claim quotes the old wording in its
      # own cell, which otherwise credits the file with everything the
      # correction just moved away from it.
      claim=$(strip_quoted <<<"$claim")
      # Backticked paths are stripped for term harvesting but KEPT for the
      # re-attribution test below. A path segment is not an option name — the
      # word "modules" harvested out of `modules/darwin/homebrew/default.nix`
      # is check 1's subject, not this check's — while the path itself is the
      # only signal that says where the option went.
      local claim_terms; claim_terms=$(sed -E 's#`[^`]*/[^`]*`##g' <<<"$claim")
      local missing="" term
      # Backticked identifiers plus bare lowercase words: the documented
      # instances of this class are stated in prose ("Homebrew taps/brews/casks,
      # launch agents"), so a backtick-only reading misses them entirely.
      for term in $(grep -oE '`[a-zA-Z][a-zA-Z0-9_.*-]*`|[a-z][a-z]{3,}' <<<"$claim_terms" | tr -d '`' | sort -u); do
        is_placeholder "$term" && continue
        [[ "$term" == *.nix ]] && continue
        # Words that describe the table itself rather than any option. Kept
        # short and literal; anything longer is a stop-word list pretending to
        # be a check.
        [[ "$term" =~ ^(options?|roles?|above|below|side|only|that|this|with|from|imported|additions)$ ]] && continue
        local leaf="${term##*.}"
        grep -qE "(^|[[:space:].{])${leaf}[[:space:].]*=" "$REPO/$file" && continue
        grep -qF -- "$leaf" "$REPO/$file" && continue
        grep -lE "(^|[[:space:].{])${leaf}[[:space:].]*=" $nixfiles >/dev/null 2>&1 || continue
        # Re-attribution, not staleness — and this is the half of the
        # quoted-span design that quoting could not carry. A corrected row says
        # where the option ACTUALLY lives, and that explanation is unquoted
        # prose, so stripping quotes leaves it credited with everything it just
        # moved away. What separates the two cases is that a corrected row NAMES
        # the destination file: the term appearing beside another .nix path that
        # holds it is the row doing its job. Same two-tier test as the credited
        # file above (assignment, else mention), applied to the file the row
        # points at, so the standard is symmetric rather than laxer.
        local other reattributed=0
        for other in $(grep -oE '`[A-Za-z0-9_./-]+\.nix`' <<<"$claim" | tr -d '`'); do
          [[ "$other" == "$file" || ! -f "$REPO/$other" ]] && continue
          grep -qF -- "$leaf" "$REPO/$other" && { reattributed=1; break; }
        done
        (( reattributed )) && continue
        missing="$missing $term"
      done
      if [[ -n "$missing" ]]; then
        emit REVIEW doc-attribution "$(basename "$doc"):$n credits $file with:$missing — each is a real option name elsewhere in the tree but absent from that file. Either it moved or the row is stale; a row may legitimately describe an effect rather than a literal option, so confirm before editing."
        flagged=$((flagged + 1))
      fi
    # The claim is cells 3 onward, never the whole line: cell 2 holds the path
    # being credited, and reading it as part of the claim makes every row credit
    # its own filename's segments ("home" from `roles/home/…`) to itself.
    done < <(awk -F'|' '/^\|/ && NF>2 {
               if (match($2, /`[^`]+\.nix`/)) {
                 c=""; for (i=3; i<=NF; i++) c = c " " $i;
                 printf "%s\t%s\t%s\n", NR, substr($2, RSTART+1, RLENGTH-2), c
               }}' "$doc")
  done
  [[ $flagged -eq 0 ]] && emit OK doc-attribution "$rows table row(s) crediting a .nix file check out against that file"
}

# --- Check 3: retired vocabulary ----------------------------------------------
# CHECKOUT mode. A term the documents themselves declare abolished, still in use
# outside the sentence that abolishes it. Headings are where this survives,
# because a heading is not prose anyone re-reads.
#
# The denylist is hand-seeded and that cost is real, but nothing else reaches
# this class: the term is spelled correctly and named something that once
# existed, so no existence check sees it. Seeds come from the documents' own
# abolition sentences — harvest new ones the same way when a term is retired.
check_retired_vocab() {
  local doc hits=0 n line
  local -a seeds=(
    $'profile\thome-manager profile|profile string|there is no|no longer one|not a profile'
    $'users/\tthere is no|no `users/`'
    $'extraHomeImports\tno separate|there is no'
    $'docs/local\tretired location|superseded|predate|find artifacts there|cleanup can destroy'
    $'pgrep -x claude\tmatches nothing|do not detect|always come|failed to fire|blamed'
  )
  for doc in "${DOCS[@]}"; do
    local s term excl
    for s in "${seeds[@]}"; do
      term="${s%%$'\t'*}"; excl="${s#*$'\t'}"
      while IFS=: read -r n line; do
        [[ -z "$line" ]] && continue
        grep -qiE "$excl" <<<"$line" && continue
        emit REVIEW doc-vocab "$(basename "$doc"):$n uses retired term '$term' outside the sentence that retires it — $(cut -c1-84 <<<"${line#"${line%%[![:space:]]*}"}")"
        hits=$((hits + 1))
      done < <(grep -nF -- "$term" "$doc")
    done
  done
  [[ $hits -eq 0 ]] && emit OK doc-vocab "no seeded retired term appears outside its own abolition sentence"
}

# --- Check 4: prescription refuted by live policy -----------------------------
# LIVE mode. A document that prescribes a command the deny list blocks does not
# merely go stale — it errors at the moment of use, having already spent the
# reader's trust. Precise, because deny patterns are literal globs.
#
# The one discrimination that matters: plenty of documented commands are for the
# USER to run, and a deny that stops Claude says nothing about those. When the
# surrounding prose marks it as a manual step, this is REVIEW rather than FAIL.
check_denied_prescriptions() {
  if [[ $LIVE -eq 0 ]]; then
    emit REVIEW doc-prescription "CHECKOUT mode — no deployed harness to read permissions.deny from, so prescribed commands were not matched against policy. Skipped, not passed."
    return
  fi
  if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
    emit REVIEW doc-prescription "settings.json unreadable at $SETTINGS — prescribed commands could not be matched against permissions.deny. Skipped, not passed. If config-checks.sh also reported a missing settings.json, fix that first."
    return
  fi
  local doc n cmd hits=0 checked=0
  local -a denies
  mapfile -t denies < <(jq -r '.permissions.deny[]? | select(startswith("Bash(")) | .[5:-1]' "$SETTINGS")
  [[ ${#denies[@]} -eq 0 ]] && { emit REVIEW doc-prescription "permissions.deny holds no Bash() patterns — nothing to match against."; return; }
  for doc in "${DOCS[@]}"; do
    while IFS=: read -r n cmd; do
      [[ -z "$cmd" ]] && continue
      checked=$((checked + 1))
      local d
      for d in "${denies[@]}"; do
        # shellcheck disable=SC2053
        [[ "$cmd" == $d ]] || continue
        # "by hand", "yourself", "manual" in the lead-in means the user runs it.
        local lead; lead=$(sed -n "$(( n > 4 ? n-4 : 1 )),${n}p" "$doc")
        if grep -qiE 'by hand|yourself|manually|the user (runs|does)|one-time|once:' <<<"$lead"; then
          emit REVIEW doc-prescription "$(basename "$doc"):$n documents '$(cut -c1-60 <<<"$cmd")', which permissions.deny blocks via '$d'. The lead-in marks it a manual step, so this is probably correct — confirm the document says plainly that Claude cannot run it."
        else
          emit FAIL doc-prescription "$(basename "$doc"):$n prescribes '$(cut -c1-60 <<<"$cmd")', which permissions.deny blocks via '$d' — deny wins, so the documented command cannot run"
          hits=$((hits + 1))
        fi
        break
      done
    done < <(awk '/^```/{inf=!inf; next}
                  inf && /^[a-z]/ && !/^#/ { line=$0; gsub(/\\$/, "", line); printf "%s:%s\n", NR, line }' "$doc")
  done
  [[ $hits -eq 0 ]] && emit OK doc-prescription "$checked fenced command line(s) checked; none that Claude is told to run is blocked by permissions.deny"
}

# --- Check 5: unfalsifiable clause --------------------------------------------
# CHECKOUT mode, advisory. A hedge cannot be violated, so it occupies the
# authority of a rule without carrying the obligation of one. Reported for the
# whole document rather than only inside hard-requirements sections: the known
# instance sits in an UNBANNERED section, so restricting to bannered ones — the
# obvious reading — finds nothing. Check 6 supplies the banner weighting.
check_unfalsifiable() {
  local doc n line hits=0
  local hedges='use your judgment|as appropriate|when reasonable|where sensible|if appropriate|as you see fit'
  for doc in "${DOCS[@]}"; do
    local banner=""
    while IFS=: read -r n line; do
      [[ -z "$line" ]] && continue
      # Is a hard-requirements banner in force at this line?
      banner=$(awk -v target="$n" '
        /hard requirements?.*not suggestions/ {inforce=1}
        /^#{1,3} / && NR>1 {inforce=0}
        NR==target {print (inforce ? "inside a hard-requirements section" : "")}' "$doc")
      local orig; orig=$(sed -n "${n}p" "$doc")
      emit REVIEW doc-unfalsifiable "$(basename "$doc"):$n hedges${banner:+ $banner} — no behavior violates it: $(cut -c1-80 <<<"${orig#"${orig%%[![:space:]]*}"}")"
      hits=$((hits + 1))
    done < <(strip_quoted_numbered "$doc" | grep -iE "$hedges")
  done
  [[ $hits -eq 0 ]] && emit OK doc-unfalsifiable "no unfalsifiable hedge clause found"
}

# --- Check 6: priority marker coverage ----------------------------------------
# CHECKOUT mode, and NOT a finding on its own — a multiplier. If some sections
# carry a hard-requirements banner and others do not, the banner cannot
# arbitrate a conflict between a labelled and an unlabelled rule, which is
# exactly the arbitration a reader will attempt. Emitted so the model-read pass
# can weight its own findings by it.
check_priority_markers() {
  local doc secs banners
  for doc in "${DOCS[@]}"; do
    secs=$(grep -cE '^## ' "$doc"); banners=$(grep -cE 'hard requirements?.*not suggestions' "$doc")
    [[ $secs -eq 0 || $banners -eq 0 || $banners -ge $secs ]] && continue
    emit REVIEW doc-priority "$(basename "$doc"): $banners of $secs top-level sections carry the hard-requirements banner, so it cannot arbitrate a labelled-vs-unlabelled conflict. Treat as a WEIGHT on other findings in this document, never as a finding on its own."
  done
}

# --- Check 7: candidates for the stated-but-unenforced class -------------------
# CHECKOUT mode, and a HANDOFF rather than a verdict. The class is: a rule whose
# subject is Claude's own procedure that leaves no artifact when followed.
# Compliance and violation are then indistinguishable in the record, so only a
# transcript comparison separates them — skill-reviewer's job, not this script's.
#
# Restricted to PROHIBITIONS, deliberately. "Never do X" provably leaves no
# artifact: not doing something produces nothing. Positive procedural
# preconditions ("run <cmd> before proposing a rule") belong to the same class
# but cannot be separated from compliant runs by text, so they are OUT OF SCOPE
# here rather than guessed at — stated so the gap is visible.
check_unenforced_candidates() {
  local doc n line total=0
  for doc in "${DOCS[@]}"; do
    local c=0 lines=""
    while IFS=: read -r n line; do
      [[ -z "$line" ]] && continue
      # An obligation to produce something IS checkable afterwards. Word
      # boundaries matter: substring matching reads "rewrite" as "write" and
      # drops a genuine candidate.
      # Stripped first: a bullet whose correction quotes the word "said" or
      # "report" would otherwise exempt itself on someone else's obligation.
      grep -qiE '\b(print|write|report|state|say|record|surface|hand over)\b' <<<"$(strip_quoted <<<"$line")" && continue
      c=$((c + 1)); total=$((total + 1)); lines="$lines $n"
      [[ $c -ge 12 ]] && break
    done < <(grep -nE '^\s*[-*] \*\*(Never|Do NOT|Do not|Don.t)' "$doc")
    [[ $c -gt 0 ]] && emit REVIEW doc-unenforced "$(basename "$doc"): $c prohibition(s) leave no artifact when followed, so compliance is invisible in the record — lines$lines. Not a defect. Hand this list to skill-reviewer, which owns behavioral evidence; do not decide it here."
  done
  [[ $total -eq 0 ]] && emit OK doc-unenforced "every prohibition names an artifact that makes compliance checkable"
}

if [[ ${#DOCS[@]} -eq 0 ]]; then
  emit REVIEW doc-inputs "no instruction document found — looked for $REPO_DOC and $GLOBAL_DOC. Nothing was checked."
  exit 0
fi

emit OK doc-inputs "$( ((LIVE)) && echo LIVE || echo CHECKOUT ) mode over ${#DOCS[@]} document(s): $(printf '%s ' "${DOCS[@]##*/}")"
check_referents
check_attribution
check_retired_vocab
check_denied_prescriptions
check_unfalsifiable
check_priority_markers
check_unenforced_candidates

# --- Deliberately not here ----------------------------------------------------
# Two candidate checks were written, failed to reproduce their own known
# instance, and were cut rather than shipped:
#
#   Dangling cross-reference ("Refer to X for Y" where X has no Y). The known
#   instance is "Refer to CLAUDE.md for full command reference." Word-level
#   matching passes it, because "full", "command" and "reference" all occur
#   somewhere in a 500-line document; and "CLAUDE.md" ambiguously names two
#   files here, which is itself part of the finding. Needs a reader, not a grep.
#
#   False behavioral claim (the referent exists, the claimed behavior does not —
#   e.g. a hook whose name, file, and registration are all correct while the
#   behavior attributed to it is absent). The only mechanical proxy is grepping
#   the named script for a keyword from the claim, which is too imprecise to
#   report and too weak to trust.
#
# Both moved to references/instruction-doc-rubric.md, which is read by a model
# rather than executed. That is not a downgrade: the classes that need judgment
# are the majority of this taxonomy, and the rubric is where they belong.
exit 0
