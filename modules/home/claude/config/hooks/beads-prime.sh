#!/usr/bin/env bash
#
# beads-prime.sh — give a beads-arm session its `bd prime` context, and stay
# silent everywhere else.
#
# Prints only when all three hold:
#   (a) `bd` is on PATH — a host not yet rebuilt has none;
#   (b) the repo has a beads database (`bd list --limit 1` exits 0);
#   (c) arms.tsv has no rows for this repo, or this branch's row says `beads`.
#       A gated repo's unlisted branch is control: priming it would contaminate
#       the arm the trial compares against. beads-trial.sh makes the same call.
#
# A session never waits on beads: the bd calls run under a LIMIT-second bound
# and a run that hits it prints nothing. 3 s is max(3 s, 3 × the 0.148 s median
# measured in the monorepo spike). The settings registration caps the whole
# hook at 5 s on top of that.
#
# There is no `timeout` binary on macOS, and procps is not declared anywhere in
# this config, so the bound is plain bash: background job plus a watchdog.

set -uo pipefail

# A hook invocation passes no arguments. A mistyped flag would otherwise run the
# live body and exit 0 — silence that reads as a pass.
if [ -n "${1:-}" ] && [ "$1" != --selftest ]; then
  echo "unknown argument: $1 (the only flag is --selftest)" >&2
  exit 2
fi

LIMIT=3
# Overridable for the selftest's stub; nothing else sets it.
BD="${BEADS_PRIME_BD:-bd}"
ARMS="${BEADS_TRIAL_DIR:-${MY_AGENT_ARTIFACTS_ROOT:-/nonexistent}/dotfiles/beads-trial}/arms.tsv"

if [ "${1:-}" = --selftest ]; then
  SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  # `mktemp -d` with no template ignores TMPDIR on macOS and lands where the
  # Claude Code sandbox denies writes.
  TMP=""
  for base in "${TMPDIR:-}" /tmp /private/tmp; do
    [ -n "$base" ] && [ -d "$base" ] || continue
    TMP=$(mktemp -d "$base/beads-prime-XXXXXX" 2>/dev/null) && break
  done
  [ -n "$TMP" ] || {
    echo "selftest: no writable temp directory" >&2
    exit 1
  }
  trap 'rm -r "$TMP"' EXIT

  mkdir -p "$TMP/bin" "$TMP/trial" "$TMP/plain"
  cat >"$TMP/bin/bd" <<'STUB'
#!/usr/bin/env bash
case "$1" in
list) exit "${STUB_LIST_RC:-0}" ;;
prime)
  [ -n "${STUB_SLEEP:-}" ] && exec sleep "$STUB_SLEEP"
  echo "PRIME TEXT"
  ;;
esac
STUB
  chmod +x "$TMP/bin/bd"

  repo() { # $1 = dir, $2 = remote repo name, $3 = branch (unborn is enough)
    git init -q "$1" && git -C "$1" remote add origin "git@example.com:me/$2.git" &&
      git -C "$1" symbolic-ref HEAD "refs/heads/$3"
  }
  repo "$TMP/free" free main
  repo "$TMP/beads" fx feat/beads
  repo "$TMP/control" fx feat/control
  repo "$TMP/unlisted" fx feat/unlisted
  printf 'repo\tbranch\tarm\tdate\n' >"$TMP/trial/arms.tsv"
  printf 'fx\tfeat/beads\tbeads\t2026-11-18\n' >>"$TMP/trial/arms.tsv"
  printf 'fx\tfeat/control\tcontrol\t2026-11-18\n' >>"$TMP/trial/arms.tsv"

  pass=0 fail=0
  # $1 desc, $2 dir, $3 expected stdout ("" = silence), then env assignments.
  check() {
    local desc="$1" dir="$2" want="$3" out rc
    shift 3
    out=$(cd "$dir" && env BEADS_TRIAL_DIR="$TMP/trial" BEADS_PRIME_BD="$TMP/bin/bd" "$@" \
      bash "$SELF" 2>/dev/null)
    rc=$?
    if [ "$out" = "$want" ] && [ "$rc" -eq 0 ]; then
      pass=$((pass + 1))
      printf '  ok    %s\n' "$desc"
    else
      fail=$((fail + 1))
      printf '  FAIL  %s (exit %s, expected "%s", got "%s")\n' "$desc" "$rc" "$want" "$out"
    fi
  }

  check "no-bd: silent" "$TMP/beads" "" BEADS_PRIME_BD=/nonexistent/bd
  check "not a git repo: silent" "$TMP/plain" ""
  check "ungated-repo: primed" "$TMP/free" "PRIME TEXT"
  check "gated-beads-branch: primed" "$TMP/beads" "PRIME TEXT"
  check "gated-control-branch: silent" "$TMP/control" ""
  check "unlisted-branch in a gated repo: silent" "$TMP/unlisted" ""
  check "no beads database: silent" "$TMP/free" "" STUB_LIST_RC=1

  start=$SECONDS
  check "timeout: silent" "$TMP/beads" "" STUB_SLEEP=10
  took=$((SECONDS - start))
  if [ "$took" -le $((LIMIT + 1)) ]; then
    pass=$((pass + 1))
    printf '  ok    %s\n' "timeout: returned within the bound + 1 s (${took} s)"
  else
    fail=$((fail + 1))
    printf '  FAIL  %s\n' "timeout: took ${took} s, bound is $((LIMIT + 1)) s"
  fi

  if bash "$SELF" --nonsense >/dev/null 2>&1; then
    fail=$((fail + 1))
    printf '  FAIL  %s\n' "an unknown flag is rejected"
  else
    pass=$((pass + 1))
    printf '  ok    %s\n' "an unknown flag is rejected"
  fi

  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
  exit $?
fi

command -v "$BD" >/dev/null 2>&1 || exit 0
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
url=$(git -C "$top" remote get-url origin 2>/dev/null) || url=$top
repo=$(basename "$url" .git)
branch=$(git -C "$top" symbolic-ref -q --short HEAD 2>/dev/null)

# Gated repo: the branch's own row decides, latest row wins. A detached HEAD has
# no branch, so it matches no row and stays silent.
if [ -f "$ARMS" ] && awk -F'\t' -v r="$repo" '$1 == r { f = 1 } END { exit !f }' "$ARMS"; then
  arm=$(awk -F'\t' -v r="$repo" -v b="$branch" '$1 == r && $2 == b { a = $3 } END { print a }' "$ARMS")
  [ "$arm" = beads ] || exit 0
fi

out=$(mktemp "${TMPDIR:-/tmp}/beads-prime.XXXXXX" 2>/dev/null) || exit 0
trap 'rm -f "$out"' EXIT

# Every background process gets /dev/null for stdout and stderr. One that held
# the hook's own stdout would keep the pipe open, and the harness would wait for
# it — the very stall the bound exists to prevent. `exec` makes the job's PID bd
# itself during prime, so the watchdog's kill lands on the process doing the work.
(
  "$BD" list --limit 1 || exit 1
  exec "$BD" prime >"$out"
) </dev/null >/dev/null 2>&1 &
job=$!
(
  sleep "$LIMIT"
  kill -TERM "$job"
) </dev/null >/dev/null 2>&1 &
dog=$!

if wait "$job"; then
  kill "$dog" 2>/dev/null
  cat "$out"
else
  kill "$dog" 2>/dev/null
fi
exit 0
