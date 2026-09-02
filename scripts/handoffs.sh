#!/bin/sh
# Shared path/scan logic for the handoff family of skills.
# usage: handoffs.sh dir  [legacy|done]     -> print the project's handoff directory
#        handoffs.sh scan [legacy|done]     -> one line per handoff:
#                                              slug<TAB>updated<TAB>lines<TAB>status<TAB>first Goal paragraph
#        handoffs.sh context-check          -> UserPromptSubmit hook: suggest handoff:save when context usage is high
# The second argument selects which area to look at:
#   (none)   the active handoffs   ~/.handoffs/<slug>/
#   done     the sealed archive    ~/.handoffs/<slug>/done/   (finish moves files here)
#   legacy   the pre-1.5 Claude-only path ~/.claude/projects/<slug>/handoffs/
#            (only the migrate skill passes this)
# Sealing is a physical fact, not a parsed flag: a file under done/ is closed, full
# stop. resume and save therefore cannot pick one up by accident. The Status line
# inside each file records why it closed (done/abandoned) for humans reading it.
set -eu

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
slug=$(printf '%s' "$root" | tr '/' '-')
dir="$HOME/.handoffs/$slug"
legacy_dir="$HOME/.claude/projects/$slug/handoffs"

target="$dir"
case "${2:-}" in
  legacy) target="$legacy_dir" ;;
  done)   target="$dir/done" ;;
esac

case "${1:-}" in
  dir)
    printf '%s\n' "$target"
    ;;
  scan)
    for f in "$target"/HANDOFF-*.md; do
      [ -e "$f" ] || continue
      s=$(basename "$f" .md); s=${s#HANDOFF-}
      updated=$(stat -c '%y' "$f" 2>/dev/null | cut -d' ' -f1)
      [ -n "$updated" ] || updated=$(stat -f '%Sm' -t '%Y-%m-%d' "$f")
      lines=$(wc -l < "$f" | tr -d ' ')
      status=$(sed -n 's/^\*\*Status\*\*:[[:space:]]*\([A-Za-z]*\).*/\1/p' "$f" | head -n 1)
      [ -n "$status" ] || status=active
      goal=$(awk '/^#+ *Goal/{g=1; next}
                  g && /^#/{exit}
                  g && !NF{if(got) exit; next}
                  g {sub(/^ +/,""); gsub(/\t/," "); out=out (got?" ":"") $0; got=1}
                  END{print out}' "$f")
      printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$updated" "$lines" "$status" "$goal"
    done
    ;;
  context-check)
    # Reads the UserPromptSubmit hook payload on stdin and suggests handoff:save
    # as the session's context fills up. Three bands, each firing at most once per
    # session (the marker file records the highest band already fired):
    #   band 1 (default 35%) -> green  tag, gentle suggestion
    #   band 2 (default 50%) -> orange tag, firmer suggestion
    #   band 3 (default 75%) -> red    tag, strongest suggestion
    # Every band only ever SUGGESTS — nothing is saved without the user asking.
    input=$(cat 2>/dev/null || true)
    transcript=$(printf '%s' "$input" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    session=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then exit 0; fi

    band1="${HANDOFF_BAND_1:-35}"
    band2="${HANDOFF_BAND_2:-50}"
    band3="${HANDOFF_BAND_3:-75}"

    # Claude transcripts do not expose a context-window field, but assistant
    # messages do record the model. Keep the exceptional 1M models explicit;
    # every other Claude model safely defaults to the standard 200K window.
    # HANDOFF_CONTEXT_LIMIT remains an escape hatch for custom deployments.
    claude_model_context_map='claude-fable-5 1000000
claude-mythos-5 1000000
claude-opus-5 1000000
claude-sonnet-5 1000000
claude-opus-4-8 1000000
claude-opus-4-7 1000000
claude-opus-4-6 1000000
claude-sonnet-4-6 1000000'

    # Context size = the last recorded usage entry. Claude and Codex transcripts use
    # different shapes for the same underlying value — see §9.4 of the design doc:
    #   Claude: input_tokens EXCLUDES cache, so cache_read + cache_creation must be added.
    #   Codex:  last_token_usage.input_tokens ALREADY INCLUDES cache — adding
    #           cached_input_tokens again would double-count. Do not "fix" this later.
    # Codex transcripts carry model_context_window (Claude's never do), so that single
    # field is what distinguishes the two formats below.
    tail_chunk=$(tail -n 200 "$transcript" 2>/dev/null || true)

    if printf '%s' "$tail_chunk" | grep -q '"model_context_window"'; then
      codex_chunk="$tail_chunk"
    elif grep -q '"model_context_window"' "$transcript" 2>/dev/null; then
      codex_chunk=$(cat "$transcript")
    else
      codex_chunk=""
    fi

    # Hosts type the command differently: "/handoff:save" on Claude Code,
    # "$handoff:save" on Codex. Both hosts register this same hook (confirmed via
    # a live Codex install's config.toml, contra the earlier "Claude-only" assumption),
    # so reuse the transcript-shape detection above rather than always defaulting to
    # "/". HANDOFF_CMD_PREFIX still overrides this for any host whose transcript this
    # detection cannot classify.
    default_prefix='/'
    [ -n "$codex_chunk" ] && default_prefix='$'
    prefix="${HANDOFF_CMD_PREFIX:-$default_prefix}"

    if [ -n "$codex_chunk" ]; then
      last_line=$(printf '%s\n' "$codex_chunk" | grep '"type":"token_count"' | tail -n 1)
      inner=$(printf '%s' "$last_line" | sed -n 's/.*"last_token_usage":{\([^}]*\)}.*/\1/p')
      used=$(printf '%s' "$inner" | sed -n 's/.*"input_tokens":\([0-9]*\).*/\1/p')
      codex_limit=$(printf '%s' "$last_line" | sed -n 's/.*"model_context_window":\([0-9]*\).*/\1/p')
      limit="${codex_limit:-${HANDOFF_CONTEXT_LIMIT:-200000}}"
    else
      model_awk='
        {
          # Match message.model structurally. Quotes embedded in message content
          # are escaped, so they cannot masquerade as this top-level field.
          if (match($0, /"message"[[:space:]]*:[[:space:]]*\{[[:space:]]*"model"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
            value=substr($0, RSTART, RLENGTH)
            sub(/^.*"model"[[:space:]]*:[[:space:]]*"/, "", value)
            sub(/"$/, "", value)
            model=value
          }
        }
        END { print model }'
      claude_model=$(printf '%s\n' "$tail_chunk" | awk "$model_awk")
      [ -n "$claude_model" ] || claude_model=$(awk "$model_awk" "$transcript")
      detected_limit=$(printf '%s\n' "$claude_model_context_map" | awk -v model="$claude_model" \
        '$1 == model { print $2; exit }')
      limit="${HANDOFF_CONTEXT_LIMIT:-${detected_limit:-200000}}"

      usage_awk='
        /"input_tokens"/ {
          i=r=c=0
          if (match($0, /"input_tokens":[0-9]+/))                i=substr($0, RSTART+15, RLENGTH-15)
          if (match($0, /"cache_read_input_tokens":[0-9]+/))     r=substr($0, RSTART+26, RLENGTH-26)
          if (match($0, /"cache_creation_input_tokens":[0-9]+/)) c=substr($0, RSTART+30, RLENGTH-30)
          last=i+r+c
        }
        END { print last+0 }'
      used=$(printf '%s\n' "$tail_chunk" | awk "$usage_awk")
      [ "${used:-0}" -le 0 ] 2>/dev/null && used=$(awk "$usage_awk" "$transcript")
    fi
    [ -n "${used:-}" ] || used=0
    case "$used" in ''|*[!0-9]*) used=0;; esac
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
      1) tag='🟢'; suffix="${prefix}handoff:save 사용을 추천합니다"
         ask="briefly mention that now is a good moment to run ${prefix}handoff:save, in one short sentence" ;;
      2) tag='🟠'; suffix="${prefix}handoff:save 사용을 권장합니다"
         ask="recommend running ${prefix}handoff:save fairly clearly — context is half gone — in one or two short sentences" ;;
      3) tag='🔴'; suffix="${prefix}handoff:save 를 사용하여 컨텍스트를 관리하세요"
         ask="clearly advise that context is running low and that using ${prefix}handoff:save now is strongly recommended to manage context, in one short sentence. Do NOT phrase it as a yes/no question and do NOT save anything yourself" ;;
    esac

    banner="$tag [handoff] 컨텍스트 ${pct}% 사용 중 (${used}/${limit} 토큰) — ${suffix}"
    context="[handoff plugin] $tag Context usage is at ~${pct}% (${used} of ${limit} tokens). Before answering the user's request, prefix your reply with the tag $tag and $ask. Keep it to one line, write it in the user's language, and never claim a handoff was saved unless you actually saved one. Then handle the request as normal. This notice fires once per band per session."

    printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' \
      "$banner" "$(printf '%s' "$context" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    ;;
  *)
    echo "usage: handoffs.sh dir|scan [legacy|done] , or context-check" >&2
    exit 2
    ;;
esac
