---
description: Write or update a handoff document so the next agent with fresh context can continue this work. Use when wrapping up a session, switching tasks, or asked to leave notes for a future conversation. Pass an optional title to target a specific handoff. Siblings — /handoff:list to see existing handoffs, /handoff:resume to continue from one, /handoff:delete to remove one.
argument-hint: "[title]"
allowed-tools:
  - Bash(sh:*), Bash(echo:*)
---

## The handoff family

This skill **writes** handoffs. Listing, resuming, and deleting are sibling skills in this plugin. If the argument here is `list`, `resume`, or `delete` (an old-style invocation), read and follow `${CLAUDE_PLUGIN_ROOT}/commands/<that-word>.md` instead.

All four skills share one script, so paths and scans are computed identically everywhere:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir   # print this project's handoff directory
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan  # one line per handoff: slug, updated date, first Goal paragraph
```

(`${CLAUDE_PLUGIN_ROOT}` is this plugin's installation directory. If the variable is unavailable, the plugin root is two directories above this skill's base directory.)

## Location

Handoff files are **personal session-continuity notes**, so they live **outside the repo** — in your home area under a per-project directory, the same place Claude Code keeps project memory: `~/.claude/projects/<project-slug>/handoffs/`.

The script derives `<project-slug>` from the **git root** (fallback: the working directory when not in a git repo), with every `/` replaced by `-`. Git root, not cwd, so a session started in a subdirectory still finds earlier handoffs.

## Files

Every handoff is a named file: `$dir/HANDOFF-<slug>.md`, one per task. There is no special "default" file — a default conflates "the only task" with "an unnamed task", which breaks down the moment parallel work appears. And no index file — listings come from `scan` on demand, so nothing can go stale.

`<slug>` is short kebab-case (2–4 words). When the user supplies a title, slugify it (lowercase, spaces → hyphens). When they don't, derive it from the handoff's **Goal** — pick the words that distinguish this task (Goal "Migrate auth from sessions to JWT" → `auth-jwt-migration`).

## Resolve the target file

1. Get `$dir` from the script and ensure it exists with `mkdir -p "$dir"`.
2. If the user gave a title, that decides the file — read it first if it exists, then update.
3. Otherwise, run `scan` and judge whether an existing handoff covers the **same work** you're handing off now (read the full file when the Goal summary isn't enough to tell):
   - Same work → update that file.
   - Clearly new work → create a new file with a slug derived from the new Goal.
   - Genuinely unsure → ask via AskUserQuestion: update the closest existing handoff, or create a new one.

## Write the document

Create or update the document with:

- **Goal**: What we're trying to accomplish
- **Current Progress**: What's been done so far
- **What Worked**: Approaches that succeeded
- **What Didn't Work**: Approaches that failed (so they're not repeated)
- **Next Steps**: Clear action items for continuing

When updating an existing file, merge rather than blindly overwrite:

- **Current Progress** and **Next Steps** reflect the latest state — rewrite them.
- **What Worked** and **What Didn't Work** accumulate — append new findings, never drop old ones.
- **Goal** rarely changes — leave it unless the task itself has shifted.

## After saving

Tell the user two things, so the next conversation needs no remembered paths:

1. The **full, expanded** file path (with `$HOME` and the slug resolved).
2. The resume command: `/handoff:resume <slug>`.
