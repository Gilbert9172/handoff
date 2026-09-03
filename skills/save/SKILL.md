---
name: save
description: Write or update a handoff document so the next agent with fresh context can continue this work. Use when wrapping up a session, switching tasks, or asked to leave notes for a future conversation. Pass an optional title to target a specific handoff, or --compact to condense one that has grown large. Siblings — the list skill shows existing handoffs, resume continues from one, finish seals a completed one, delete removes one.
argument-hint: "[title] [--compact]"
allowed-tools:
  - Bash(sh:*), Bash(echo:*)
---

## The handoff family

This skill **writes** handoffs. Listing, resuming, sealing, and deleting are sibling skills in this plugin. If the argument here is `list`, `resume`, `finish`, or `delete` (an old-style invocation), read and follow `${CLAUDE_PLUGIN_ROOT}/skills/<that-word>/SKILL.md` instead.

All skills share one script, so paths and scans are computed identically everywhere:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir        # this project's handoff directory
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir done   # the sealed archive
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan       # one line per active handoff:
                                                          # slug, updated, lines, status, first Goal paragraph
```

(`${CLAUDE_PLUGIN_ROOT}` is this plugin's installation directory. If the variable is unavailable, the plugin root is two directories above this skill's base directory.)

## Arguments

An argument starting with `--` is an option; anything else is a title. Order doesn't matter, and both are optional.

- `--compact` — condense this handoff's accumulated history as part of saving. See **Compacting** below.

## Location

Handoff files are **personal session-continuity notes**, so they live **outside the repo** — in your home area under a per-project directory: `~/.handoffs/<project-slug>/`. This path is host-neutral (not tied to `~/.claude` or `~/.codex`) so the same notes are reachable from either.

The script derives `<project-slug>` from the **git root** (fallback: the working directory when not in a git repo), with every `/` replaced by `-`. Git root, not cwd, so a session started in a subdirectory still finds earlier handoffs.

## Files

Every handoff is a named file: `$dir/HANDOFF-<slug>.md`, one per task. There is no special "default" file — a default conflates "the only task" with "an unnamed task", which breaks down the moment parallel work appears. And no index file — listings come from `scan` on demand, so nothing can go stale.

`<slug>` is short kebab-case (2–4 words). When the user supplies a title, slugify it (lowercase, spaces → hyphens). When they don't, derive it from the handoff's **Goal** — pick the words that distinguish this task (Goal "Migrate auth from sessions to JWT" → `auth-jwt-migration`).

Handoffs sealed by `finish` live under `$dir/done/`. They are closed: **never append to a sealed handoff.** If the work needs to continue, it is new work — create a new file.

## Resolve the target file

1. Get `$dir` from the script and ensure it exists with `mkdir -p "$dir"`.
2. If the user gave a title, that decides the file — read it first if it exists, then update.
3. Otherwise, run `scan` and judge whether an existing handoff covers the **same work** you're handing off now (read the full file when the Goal summary isn't enough to tell):
   - Same work → update that file.
   - Clearly new work → create a new file with a slug derived from the new Goal.
   - Genuinely unsure → ask via AskUserQuestion: update the closest existing handoff, or create a new one.

`scan` lists only active handoffs, so a sealed slug will never be offered as an update target. If the user explicitly names a title that turns out to be sealed (it exists under `done/` but not in `$dir`), don't reopen it — tell them it was sealed, and create a new handoff for the continuing work.

## What counts as "the same work"

A handoff tracks **one thread of work**, not a whole project or repo. The test is whether the Goal still describes what you're doing now:

- Goal holds, the path changed → same handoff. Rewrite Next Steps for the new direction and record the abandoned approach under **What Didn't Work**.
- Goal itself no longer applies → this is different work. Create a new handoff, and mention the user can seal the old one with `handoff:finish` (see **Command notation**).

Keeping the scope to one thread is what stops a single file from absorbing months of unrelated work.

## Write the document

Create or update the document with:

- **Goal**: What we're trying to accomplish
- **Current Progress**: What's been done so far
- **What Worked**: Approaches that succeeded
- **What Didn't Work**: Approaches that failed (so they're not repeated)
- **Next Steps**: Clear action items for continuing

`handoff:finish` also uses the merge rules below (for Current Progress, What Worked, What Didn't Work) when it brings a handoff's record up to date right before sealing — it just leaves Next Steps alone, since sealing removes the reader that field exists to guide.

When updating an existing file, merge rather than blindly overwrite:

- **Current Progress** and **Next Steps** reflect the latest state — rewrite them.
- **What Worked** and **What Didn't Work** accumulate — append new findings, and don't drop old ones unless you are compacting (below).
- **Goal** rarely changes — leave it unless the task itself has shifted.

## Compacting

Accumulated history is what makes a handoff useful and also what makes it grow without bound. Compacting trims it **without ending the handoff** — the work continues, so the document must stay useful to whoever picks it up next.

Compact when the user passes `--compact`, or asks for it in their own words after you mention the document's size. `handoff:finish` also runs this step automatically (no flag needed) when a handoff crosses 200 lines, right before sealing — since a sealed file never gets edited again, that's the last chance to trim it.

Be **conservative**. This document is still going to be read by an agent continuing the work:

- Condense **older** entries in What Worked / What Didn't Work into one line each, grouping ones that make the same point.
- Keep **recent** entries as they are — they're the live context.
- Never drop a failed approach entirely. Losing it means someone repeats it, which is the whole reason the section exists.
- Leave Goal, Current Progress, and Next Steps alone. They already reflect the latest state.

Show the user what the compaction removed or merged, and how many lines the file went from and to.

Compacting is not sealing. Ending a handoff for good is `handoff:finish`, which is the user's call alone — never seal a handoff yourself.

## If the write fails

If the target path can't be written (permission denied, sandbox block, disk error), do not report success and do not fall back to a different path. State plainly that the write failed, then print the **full document you were about to save** directly in the conversation — every section, not a summary. `save` typically runs right as the user is about to end the session, so a silent failure here is data loss they won't discover until the next session starts empty-handed.

## After saving

Tell the user these things, so the next conversation needs no remembered paths. In every case below, substitute the **actual** values — never print the literal placeholders `<slug>` or `$HOME`; replace them with the resolved slug and expanded path:

1. The **full, expanded** file path (with `$HOME` and the slug resolved).
2. The resume command, with the real slug filled in and this host's command prefix (see **Command notation**) — e.g. `/handoff:resume auth-jwt-migration` on Claude Code, `$handoff:resume auth-jwt-migration` on Codex. Never leave the literal `<slug>` placeholder in.
3. A note that continuing is best done in a **fresh session**: handoff exists precisely so an agent with clean context can pick up the work — so if they want to keep going, they should start a new session and run the resume command there rather than continuing in this one. Write it in the user's language with the real slug already substituted, e.g. (for slug `auth-jwt-migration`, on Claude Code): "save 완료 후 이어서 진행하실 경우, 새로운 세션에서 `/handoff:resume auth-jwt-migration` 로 이어서 해주세요."
4. That `handoff:finish <slug>` seals this handoff when the work is completely over. One line, always — the user decides when that is, so this is a signpost, not a question.
5. **Only if the file now exceeds 200 lines** (the `scan` output's third column), mention its size and offer to condense it. Say it as an offer they can answer right there — don't block the save on it, and don't compact without being asked.

Never ask a question that stops the user from leaving. `save` usually runs when context is nearly full and they're about to end the session; the save itself is already complete by this point.

## Command notation

When you print a handoff command for the user, write it with the prefix **this host** uses to invoke skills — `/handoff:resume <slug>` on Claude Code, `$handoff:resume <slug>` on Codex. Never hardcode `/`: if the user typed the invocation that started this skill, copy its prefix; otherwise use this host's own.
