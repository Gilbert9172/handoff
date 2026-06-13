#!/bin/sh
# Stop hook for the /handoff plugin.
# When a turn ends with uncommitted work in the tree, nudge Claude — once per
# session — to offer saving a handoff, so the plugin's value no longer depends
# on the user remembering to run /handoff:save. Deliberately conservative:
# fires only with real work-in-progress, only once, and tells Claude to stay
# quiet when the change is trivial.
set -eu

input=$(cat)

# Read a top-level JSON field value without requiring jq.
field() {
  printf '%s' "$input" \
    | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\{0,1\}\([^",}]*\).*/\1/p' \
    | head -n1
}

# Never re-block a session that's already being held open by Stop hooks.
[ "$(field stop_hook_active)" = "true" ] && exit 0

session=$(field session_id)
[ -n "$session" ] || session="nosession"
marker="${TMPDIR:-/tmp}/handoff-stop-$session"

# At most one nudge per session.
[ -e "$marker" ] && exit 0

# Only nudge when there's genuine work in flight: a dirty git tree.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -n "$(git status --porcelain 2>/dev/null)" ] || exit 0

: > "$marker" 2>/dev/null || true

reason="This session ends with uncommitted changes, so there may be in-progress work worth preserving for a future session. If the work is unfinished or likely to continue later, briefly offer to save a handoff with /handoff:save (one line on what you'd record). If the change is trivial or already complete, just stop normally — do not nag."

printf '{"decision":"block","reason":"%s"}\n' "$reason"
