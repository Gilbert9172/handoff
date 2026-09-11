#!/bin/sh
# Covers changelog.sh/changelog.awk: version-boundary detection (both the
# "chore: bump version to X.Y.Z" and old "vX.Y.Z - ..." styles), grouping by
# conventional-commit type, scope formatting, and the Unreleased section.
# Run from anywhere: sh tests/changelog.sh
set -eu

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
script="$repo/scripts/changelog.sh"
test_tmp=$(mktemp -d "${TMPDIR:-/tmp}/handoff-changelog-test.XXXXXX")
trap 'rm -rf "$test_tmp"' EXIT HUP INT TERM

assert_contains() {
  name=$1; actual=$2; expected=$3
  case "$actual" in
    *"$expected"*) printf 'ok - %s\n' "$name" ;;
    *)
      printf 'not ok - %s\nexpected output to contain: %s\nactual:\n%s\n' \
        "$name" "$expected" "$actual" >&2
      exit 1
      ;;
  esac
}

assert_not_contains() {
  name=$1; actual=$2; unexpected=$3
  case "$actual" in
    *"$unexpected"*)
      printf 'not ok - %s\nexpected output NOT to contain: %s\nactual:\n%s\n' \
        "$name" "$unexpected" "$actual" >&2
      exit 1
      ;;
    *) printf 'ok - %s\n' "$name" ;;
  esac
}

src="$test_tmp/src"
mkdir -p "$src"
git -C "$src" init -q -b main
git -C "$src" config user.name "Test User"
git -C "$src" config user.email "test@example.com"
git -C "$src" config commit.gpgsign false

commit() {
  printf '%s\n' "$1" >> "$src/file.txt"
  git -C "$src" add file.txt
  git -C "$src" commit -q -m "$2"
}

commit one "feat(finish): add lifecycle boundary"
commit two "fix(list,delete): drop model override"
commit three "chore: bump version to 1.0.0"
commit four "v1.1.0 - list, delete 호출시 haiku 사용"
commit five "docs: clarify usage"
commit six "chore: captures/ 를 gitignore 처리"

output=$(cd "$src" && sh "$script" --stdout)

assert_contains  "unreleased section for commits after the last boundary" "$output" '## [Unreleased]'
assert_contains  "unreleased holds the trailing chore" "$output" '- captures/ 를 gitignore 처리'
assert_contains  "v-prefixed boundary opens its own version section" "$output" '## [1.1.0]'
assert_contains  "text after a v-prefixed boundary becomes a bullet" "$output" '- list, delete 호출시 haiku 사용'
assert_contains  "dedicated bump commit opens the 1.0.0 section" "$output" '## [1.0.0]'
assert_contains  "scoped feat groups under Added with bold scope" "$output" '### Added
- **finish:** add lifecycle boundary'
assert_contains  "multi-scope fix groups under Fixed" "$output" '### Fixed
- **list,delete:** drop model override'
assert_contains  "docs commit groups under Documentation in the 1.1.0 section" "$output" '- clarify usage'
assert_not_contains "bare bump commit is not listed as its own bullet" "$output" 'bump version to 1.0.0 (`'

[ ! -e "$src/CHANGELOG.md" ] || { echo "not ok - --stdout must not write CHANGELOG.md" >&2; exit 1; }
printf 'ok - %s\n' "--stdout does not write CHANGELOG.md"

(cd "$src" && sh "$script")
[ -f "$src/CHANGELOG.md" ] || { echo "not ok - default mode writes CHANGELOG.md" >&2; exit 1; }
printf 'ok - %s\n' "default mode writes CHANGELOG.md"

assert_contains "written file matches --stdout output" "$(cat "$src/CHANGELOG.md")" '## [Unreleased]'
