#!/bin/sh
# SessionStart hook for the /handoff plugin.
# Surfaces this project's existing handoffs into the new session's context, so
# a fresh conversation knows work can be resumed without the user having to
# remember a handoff exists. Stays silent when there's nothing to resume.
set -eu

here=$(CDPATH= cd "$(dirname "$0")" && pwd)

scan=$(sh "$here/handoffs.sh" scan 2>/dev/null || true)
[ -n "$scan" ] || exit 0   # no handoffs for this project → say nothing

# "- slug (updated YYYY-MM-DD): goal" per line.
list=$(printf '%s\n' "$scan" | awk -F '\t' 'NF{printf "- %s (updated %s): %s\n", $1, $2, $3}')
[ -n "$list" ] || exit 0

ctx="This project has handoff documents saved by previous sessions. If the user wants to continue earlier work, resume one with /handoff:resume <slug> — do not proactively resume, just keep this available:
$list"

# Minimal, portable JSON string escaper (backslash, quote, tab, newline).
json_escape() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk 'BEGIN{ORS=""} {gsub(/\t/,"\\t"); if(NR>1) printf "\\n"; printf "%s",$0}'
}

esc=$(json_escape "$ctx")
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"
