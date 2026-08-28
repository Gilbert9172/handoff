#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
script="$repo/scripts/handoffs.sh"
fixtures="$repo/tests/fixtures"
test_tmp=$(mktemp -d "${TMPDIR:-/tmp}/handoff-context-test.XXXXXX")
trap 'rm -rf "$test_tmp"' EXIT HUP INT TERM

assert_contains() {
  name=$1
  actual=$2
  expected=$3
  case "$actual" in
    *"$expected"*) ;;
    *)
      printf 'not ok - %s\nexpected output to contain: %s\nactual: %s\n' \
        "$name" "$expected" "$actual" >&2
      exit 1
      ;;
  esac
  printf 'ok - %s\n' "$name"
}

run_hook() {
  transcript=$1
  session=$2
  printf '{"transcript_path":"%s","session_id":"%s"}\n' "$transcript" "$session" |
    TMPDIR="$test_tmp" sh "$script" context-check
}

output=$(run_hook "$fixtures/claude-opus-5.jsonl" opus-5)
assert_contains 'known Claude 1M model' "$output" '40% 사용 중 (400000/1000000 토큰)'

output=$(run_hook "$fixtures/claude-haiku.jsonl" haiku)
assert_contains 'unmapped Claude model defaults to 200K' "$output" '40% 사용 중 (80000/200000 토큰)'

output=$(HANDOFF_CONTEXT_LIMIT=200000 run_hook "$fixtures/claude-opus-5.jsonl" override)
assert_contains 'explicit Claude limit overrides model map' "$output" '200% 사용 중 (400000/200000 토큰)'

output=$(run_hook "$fixtures/codex.jsonl" codex)
assert_contains 'Codex transcript limit remains authoritative' "$output" '40% 사용 중 (40000/100000 토큰)'
