#!/bin/sh
# Shared path/scan logic for the /handoff family of skills.
# usage: handoffs.sh dir            -> print the project's handoff directory
#        handoffs.sh scan           -> one line per handoff: slug<TAB>updated<TAB>first Goal paragraph
#        handoffs.sh context-check  -> UserPromptSubmit hook: suggest /handoff:save when context usage is high
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
      updated=$(stat -c '%y' "$f" 2>/dev/null | cut -d' ' -f1)
      [ -n "$updated" ] || updated=$(stat -f '%Sm' -t '%Y-%m-%d' "$f")
      goal=$(awk '/^#+ *Goal/{g=1; next}
                  g && /^#/{exit}
                  g && !NF{if(got) exit; next}
                  g {sub(/^ +/,""); gsub(/\t/," "); out=out (got?" ":"") $0; got=1}
                  END{print out}' "$f")
      printf '%s\t%s\t%s\n' "$s" "$updated" "$goal"
    done
    ;;
  context-check)
    # Reads the UserPromptSubmit hook payload on stdin and suggests /handoff:save
    # as the session's context fills up. Three bands, each firing at most once per
    # session (the marker file records the highest band already fired):
    #   band 1 (default 35%) -> green  tag, gentle suggestion
    #   band 2 (default 50%) -> orange tag, firmer suggestion
    #   band 3 (default 75%) -> red    tag, ask whether to save once more
    # Every band only ever SUGGESTS — nothing is saved without the user asking.
    input=$(cat 2>/dev/null || true)
    transcript=$(printf '%s' "$input" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    session=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then exit 0; fi

    limit="${HANDOFF_CONTEXT_LIMIT:-200000}"
    band1="${HANDOFF_BAND_1:-35}"
    band2="${HANDOFF_BAND_2:-50}"
    band3="${HANDOFF_BAND_3:-75}"

    # Context size = the last recorded usage entry: input + cache tokens.
    used=$(awk '
      /"input_tokens"/ {
        i=r=c=0
        if (match($0, /"input_tokens":[0-9]+/))                i=substr($0, RSTART+15, RLENGTH-15)
        if (match($0, /"cache_read_input_tokens":[0-9]+/))     r=substr($0, RSTART+26, RLENGTH-26)
        if (match($0, /"cache_creation_input_tokens":[0-9]+/)) c=substr($0, RSTART+30, RLENGTH-30)
        last=i+r+c
      }
      END { print last+0 }' "$transcript")
    if [ "$used" -le 0 ]; then exit 0; fi

    pct=$((used * 100 / limit))
    band=0
    if   [ "$pct" -ge "$band3" ]; then band=3
    elif [ "$pct" -ge "$band2" ]; then band=2
    elif [ "$pct" -ge "$band1" ]; then band=1
    fi
    if [ "$band" -eq 0 ]; then exit 0; fi

    marker="${TMPDIR:-/tmp}/handoff-context-reminder-${session:-unknown}"
    prev=$(cat "$marker" 2>/dev/null || echo 0)
    case "$prev" in ''|*[!0-9]*) prev=0;; esac
    if [ "$band" -le "$prev" ]; then exit 0; fi
    printf '%s' "$band" > "$marker"

    case "$band" in
      1) tag='🟢'; ask="briefly mention that now is a good moment to run /handoff:save, in one short sentence" ;;
      2) tag='🟠'; ask="recommend running /handoff:save fairly clearly — context is half gone — in one or two short sentences" ;;
      3) tag='🔴'; ask="warn that context is running low and ASK the user whether to save the handoff once more (a yes/no question, e.g. \"한 번 더 저장하시겠습니까?\"). Do NOT save anything yourself — wait for the user to answer" ;;
    esac

    banner="$tag [handoff] 컨텍스트 ${pct}% 사용 중 (${used}/${limit} 토큰) — /handoff:save 권장"
    context="[handoff plugin] $tag Context usage is at ~${pct}% (${used} of ${limit} tokens). Before answering the user's request, prefix your reply with the tag $tag and $ask. Keep it to one line, write it in the user's language, and never claim a handoff was saved unless you actually saved one. Then handle the request as normal. This notice fires once per band per session."

    printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' \
      "$banner" "$(printf '%s' "$context" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    ;;
  *)
    echo "usage: handoffs.sh dir|scan|context-check" >&2
    exit 2
    ;;
esac
