#!/bin/sh
# Shared path/scan logic for the /handoff family of skills.
# usage: handoffs.sh dir   -> print the project's handoff directory
#        handoffs.sh scan  -> one line per handoff: slug<TAB>updated<TAB>first Goal paragraph
set -eu

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
slug=$(printf '%s' "$root" | tr '/' '-')
dir="$HOME/.claude/projects/$slug/handoffs"

case "${1:-}" in
  dir)
    printf '%s\n' "$dir"
    ;;
  scan)
    for f in "$dir"/HANDOFF-*.md; do
      [ -e "$f" ] || continue
      s=$(basename "$f" .md); s=${s#HANDOFF-}
      updated=$(stat -f '%Sm' -t '%Y-%m-%d' "$f" 2>/dev/null || stat -c '%y' "$f" | cut -d' ' -f1)
      goal=$(awk '/^#+ *Goal/{g=1; next}
                  g && /^#/{exit}
                  g && !NF{if(got) exit; next}
                  g {sub(/^ +/,""); out=out (got?" ":"") $0; got=1}
                  END{print out}' "$f")
      printf '%s\t%s\t%s\n' "$s" "$updated" "$goal"
    done
    ;;
  *)
    echo "usage: handoffs.sh dir|scan" >&2
    exit 2
    ;;
esac
