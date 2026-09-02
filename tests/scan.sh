#!/bin/sh
# Covers the dir/scan contract: the done/ split, the five-column TSV,
# and Status parsing. Run from anywhere: sh tests/scan.sh
set -eu

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
script="$repo/scripts/handoffs.sh"
test_tmp=$(mktemp -d "${TMPDIR:-/tmp}/handoff-scan-test.XXXXXX")
trap 'rm -rf "$test_tmp"' EXIT HUP INT TERM

HOME="$test_tmp/home"
export HOME
mkdir -p "$HOME"

assert_eq() {
  name=$1; actual=$2; expected=$3
  if [ "$actual" = "$expected" ]; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s\nexpected: %s\nactual:   %s\n' "$name" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_contains() {
  name=$1; actual=$2; expected=$3
  case "$actual" in
    *"$expected"*) printf 'ok - %s\n' "$name" ;;
    *)
      printf 'not ok - %s\nexpected output to contain: %s\nactual: %s\n' \
        "$name" "$expected" "$actual" >&2
      exit 1
      ;;
  esac
}

dir=$(sh "$script" dir)
done_dir=$(sh "$script" dir done)

assert_eq "dir done is the done/ subdirectory of dir" "$done_dir" "$dir/done"

# --- empty state -------------------------------------------------------------
mkdir -p "$dir/done"
assert_eq "scan on an empty directory prints nothing" "$(sh "$script" scan)" ""
assert_eq "scan done on an empty archive prints nothing" "$(sh "$script" scan done)" ""

# --- active handoff ----------------------------------------------------------
cat > "$dir/HANDOFF-payment-endpoint.md" <<'EOF'
# Goal
결제 승인 엔드포인트 추가

## Next Steps
- IAM 매핑
EOF

active=$(sh "$script" scan)
assert_eq "scan finds exactly one active handoff" "$(printf '%s\n' "$active" | wc -l | tr -d ' ')" "1"
assert_eq "scan emits five tab-separated fields" \
  "$(printf '%s' "$active" | awk -F'\t' '{print NF}')" "5"
assert_eq "field 1 is the slug" \
  "$(printf '%s' "$active" | cut -f1)" "payment-endpoint"
assert_eq "field 3 is the line count" \
  "$(printf '%s' "$active" | cut -f3)" "$(wc -l < "$dir/HANDOFF-payment-endpoint.md" | tr -d ' ')"
assert_eq "a file without a Status line reports active" \
  "$(printf '%s' "$active" | cut -f4)" "active"
assert_eq "field 5 is the first Goal paragraph" \
  "$(printf '%s' "$active" | cut -f5)" "결제 승인 엔드포인트 추가"

# --- sealed handoff ----------------------------------------------------------
cat > "$dir/done/HANDOFF-auth-jwt.md" <<'EOF'
**Status**: done (2026-09-01)

# Goal
세션 인증을 JWT로 전환
EOF

cat > "$dir/done/HANDOFF-rest-payments.md" <<'EOF'
**Status**: abandoned (2026-09-02) — GraphQL로 전환하여 REST 엔드포인트는 불필요

# Goal
REST 결제 엔드포인트 추가
EOF

# The whole point of the done/ split: sealed notes are invisible to the default
# scan, so list and resume cannot offer them. This is enforced by the glob, not
# by a filter — a shell glob does not descend into subdirectories.
assert_eq "sealed handoffs stay out of the default scan" \
  "$(sh "$script" scan | wc -l | tr -d ' ')" "1"
assert_eq "the default scan still only sees the active slug" \
  "$(sh "$script" scan | cut -f1)" "payment-endpoint"

sealed=$(sh "$script" scan done)
assert_eq "scan done finds both sealed handoffs" \
  "$(printf '%s\n' "$sealed" | wc -l | tr -d ' ')" "2"
assert_contains "Status: done is parsed to its first word" \
  "$(printf '%s\n' "$sealed" | grep auth-jwt | cut -f4)" "done"
assert_contains "Status: abandoned is parsed to its first word" \
  "$(printf '%s\n' "$sealed" | grep rest-payments | cut -f4)" "abandoned"
assert_eq "a reason after the date never leaks into the status field" \
  "$(printf '%s\n' "$sealed" | grep rest-payments | cut -f4)" "abandoned"

# A Status line above the first heading must not be absorbed into the Goal
# paragraph — that would pollute every listing.
assert_eq "the Status line stays out of the Goal field" \
  "$(printf '%s\n' "$sealed" | grep auth-jwt | cut -f5)" "세션 인증을 JWT로 전환"

# --- legacy path is unaffected -----------------------------------------------
legacy=$(sh "$script" dir legacy)
assert_contains "dir legacy still resolves under ~/.claude/projects" \
  "$legacy" "/.claude/projects/"

printf '\nall scan tests passed\n'
