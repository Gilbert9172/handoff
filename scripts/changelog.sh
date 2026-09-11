#!/bin/sh
# Regenerates CHANGELOG.md from this repo's git history.
# usage: changelog.sh [--stdout]
#   (no args)  write the generated changelog to CHANGELOG.md at the repo root
#   --stdout   print the generated changelog instead of writing the file
#
# Grouping logic (boundaries, categories, Unreleased) lives in changelog.awk —
# see the comment there. Run this after bumping the version in plugin.json so
# the new release commit becomes its own section.
set -eu

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
self_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
out="$root/CHANGELOG.md"

generated=$(git -C "$root" log --reverse --date=short --pretty=format:'%H%x09%ad%x09%s' \
  | awk -f "$self_dir/changelog.awk")

if [ "${1:-}" = "--stdout" ]; then
  printf '%s\n' "$generated"
else
  printf '%s\n' "$generated" > "$out"
  echo "changelog.sh: wrote $out" >&2
fi
