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

output=$(run_hook "$fixtures/claude-fable-5-1.jsonl" fable-5-1)
assert_contains 'new Claude model defaults to 1M' "$output" '40% 사용 중 (400000/1000000 토큰)'

output=$(run_hook "$fixtures/claude-haiku.jsonl" haiku)
assert_contains 'known Claude 200K model stays at 200K' "$output" '40% 사용 중 (80000/200000 토큰)'

output=$(HANDOFF_CONTEXT_LIMIT=200000 run_hook "$fixtures/claude-opus-5.jsonl" override)
assert_contains 'explicit Claude limit overrides model detection' "$output" '200% 사용 중 (400000/200000 토큰)'

output=$(run_hook "$fixtures/codex.jsonl" codex)
assert_contains 'Codex transcript limit remains authoritative' "$output" '40% 사용 중 (40000/100000 토큰)'

# Equivalent JSONL with spaces or tabs around separators must produce the same
# usage and host notation. In particular, Codex cache tokens stay included once.
for spacing in space tab; do
  case "$spacing" in
    space) padding=' ' ;;
    tab) padding=$(printf '\t') ;;
  esac
  for host in codex claude-haiku; do
    spaced="$test_tmp/$host-$spacing.jsonl"
    sed "s/\":/\"$padding:$padding/g; s/,/,$padding/g" "$fixtures/$host.jsonl" > "$spaced"
    output=$(run_hook "$spaced" "$host-$spacing")
    case "$host" in
      codex) expected='40% 사용 중 (40000/100000 토큰)'; prefix='$handoff:save' ;;
      claude-haiku) expected='40% 사용 중 (80000/200000 토큰)'; prefix='/handoff:save' ;;
    esac
    assert_contains "$host accepts $spacing in JSON separators" "$output" "$expected"
    assert_contains "$host preserves host notation with $spacing" "$output" "$prefix"
    repeated=$(run_hook "$spaced" "$host-$spacing")
    if [ -n "$repeated" ]; then
      printf 'not ok - duplicate reminder for %s\n' "$host-$spacing" >&2
      exit 1
    fi
  done
done

output=$(run_hook "$fixtures/claude-haiku.jsonl" prefix-default)
assert_contains 'Claude transcript defaults to / notation' "$output" '/handoff:save'

output=$(run_hook "$fixtures/codex.jsonl" prefix-codex)
assert_contains 'Codex transcript defaults to $ notation without any override' "$output" '$handoff:save'

output=$(HANDOFF_CMD_PREFIX='$' run_hook "$fixtures/claude-haiku.jsonl" prefix-override)
assert_contains 'HANDOFF_CMD_PREFIX overrides the Claude default' "$output" '$handoff:save'

output=$(HANDOFF_CMD_PREFIX='/' run_hook "$fixtures/codex.jsonl" prefix-override-codex)
assert_contains 'HANDOFF_CMD_PREFIX overrides the Codex default' "$output" '/handoff:save'
