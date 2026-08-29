---
name: migrate
description: One-time move of this project's handoff documents from the old Claude-only storage path (~/.claude/projects/<slug>/handoffs/) to the current host-neutral path (~/.handoffs/<slug>/). Use only when explicitly asked to migrate, move, or recover old handoffs after upgrading this plugin — never trigger this on its own. Temporary skill: it will be removed once the old path falls out of use.
disable-model-invocation: true
allowed-tools:
  - Bash(sh:*), Bash(echo:*), Bash(mkdir:*), Bash(mv:*)
---

## Why this exists

Earlier versions of this plugin stored handoffs under `~/.claude/projects/<project-slug>/handoffs/`. That path is gone — `save`, `list`, `resume`, and `delete` now only look at `~/.handoffs/<project-slug>/`. Nothing was deleted, but anything still sitting at the old path is invisible to those four skills until it's moved here.

This skill only moves files for the **current project's exact slug** (same git-root-derived slug on both sides — see below). It does not go looking for the same logical project under a different absolute path (e.g. after the repo itself was moved or re-cloned elsewhere) — if that's the situation, tell the user to move those files by hand; reconciling different slugs isn't this skill's job.

## Find both locations

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir           # current (new) directory
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir legacy    # old directory
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan          # current handoffs: slug, updated, Goal
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan legacy   # old handoffs: slug, updated, Goal
```

(`${CLAUDE_PLUGIN_ROOT}` is this plugin's installation directory. If the variable is unavailable, the plugin root is two directories above this skill's base directory.)

If `scan legacy` prints nothing, there is nothing to migrate — say so in one line and stop. This is the expected steady state for anyone who has already migrated or never had handoffs under the old path; treat it as a normal outcome, not an error.

## Build the plan

For every slug `scan legacy` lists, check whether the same slug also appears in `scan` (current):

- **Only in legacy** → clean move: `$legacy_dir/HANDOFF-<slug>.md` → `$dir/HANDOFF-<slug>.md`.
- **In both** → conflict: do not guess which one is "right." Do not merge their contents.

## Confirm before touching anything

1. If there are clean moves, list them (slug, old path, new path) and confirm once via AskUserQuestion before moving any of them — this still touches the user's files, even though nothing is destroyed.
2. For each conflicting slug, show both versions' updated date and Goal line side by side and ask via AskUserQuestion how to resolve it, per slug:
   - **Keep current, discard legacy copy** — leave `~/.handoffs/` untouched; delete nothing yet, just skip the legacy file (see reporting below).
   - **Replace current with legacy copy** — move the legacy file over the current one.
   - **Keep both** — move the legacy file to `$dir/HANDOFF-<slug>-legacy.md` instead of overwriting.
3. Never move a file the user hasn't confirmed, and never touch a slug that wasn't part of the plan you showed them.

## Execute

`mkdir -p "$dir"` if it doesn't exist yet, then `mv` exactly the confirmed files to their confirmed destinations. A `mv` empties the legacy file out of the old location as a side effect — that's expected, not a separate delete step.

## Report

State plainly, per file: the exact old path, the exact new path (or "skipped, kept the current copy" for that resolution), and whether anything failed (permission denied, disk error) — if a move fails, say so and leave that file where it was; don't report it as moved.

If the old directory is now empty, mention that it can be removed by hand — this skill does not delete directories, only the specific files it moved.
