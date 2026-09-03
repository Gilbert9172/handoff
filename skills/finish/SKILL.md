---
name: finish
description: Seal a handoff whose work is over — either the goal was reached or the approach was dropped. Brings Current Progress up to date, then moves the document into the archive so it stops appearing in list and resume, and save no longer appends to it. Use when the user says a task is completely finished or is being abandoned. Siblings — save writes handoffs, resume continues one, list shows them, delete removes them permanently.
disable-model-invocation: true
argument-hint: "[title]"
allowed-tools:
  - Bash(sh:*), Bash(echo:*), Bash(mv:*), Bash(mkdir:*), Bash(ls:*)
---

A handoff exists so a later session can pick the work back up. When there is nothing left to pick up, the document should stop being an active note — otherwise it clutters `list`, muddies `resume`'s choices, and keeps growing every time `save` appends to it.

`finish` closes that lifecycle. It **seals** a handoff: records why it ended, then moves it into the archive.

## The user decides, never you

**`finish` does not judge whether the work is done.** The user invoking this skill *is* the declaration that it's over. Your job is to bring the record up to date, show them what they're sealing, and record their decision — not to decide it for them.

In particular, leftover **Next Steps do not block sealing**. Plans go stale — the user may have changed direction mid-task, which makes the old Next Steps a discarded plan rather than unfinished work. Point out what's left, then let the user decide. A leftover item can prompt one reconfirmation (see **Ask how it ended**), never a refusal.

This skill is never invoked automatically. `save` and `resume` may *mention* it; only the user runs it.

## Resolve the target file

Run the shared script bundled with this plugin:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir        # active handoff directory
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir done   # the sealed archive
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan       # slug, updated, lines, status, first Goal paragraph
```

(`${CLAUDE_PLUGIN_ROOT}` is this plugin's installation directory. If the variable is unavailable, the plugin root is two directories above this skill's base directory.)

`scan` lists only **active** handoffs — sealed ones live under `done/` and are out of scope here.

- **With a title argument** → the file is `$dir/HANDOFF-<title-slug>.md` (title lowercased, spaces → hyphens). If it doesn't exist, show the scan results so the user can pick the right slug.
- **Without a title** → show the scan table and ask which to seal via AskUserQuestion. Ask even when only one handoff exists — sealing is a deliberate act, not a default.

## 1. Bring the record up to date

Before showing anything, make sure the document reflects what actually happened. Refresh **Current Progress**, and append to **What Worked** / **What Didn't Work** if this session found anything new — merge the same way `handoff:save` does (see that skill's **Write the document** section). If nothing has happened since the last save, there's nothing to refresh.

Leave **Next Steps** untouched. It exists to guide whoever resumes next, and once this skill finishes there is no "next" — `resume` and `list` stop seeing this file. Whatever is listed there becomes the historical record of what was left, not a plan to keep in sync.

If the file is now over 200 lines (`scan`'s line-count column), compact it the same way `handoff:save --compact` does (see that skill's **Compacting** section), and tell the user what was condensed and the line-count change, same as that skill would. Do this regardless of how the file ends up being sealed — it's document hygiene, not a judgment about the work.

## 2. Show what's being sealed

Read the file in full, then show the user, in their language:

- **Goal** — what this handoff set out to do
- **Current Progress** — where it actually got to
- **Remaining Next Steps** — every item still listed, verbatim. If there are none, say so.

Keep it short — this is context for one decision, not a report.

## 3. Ask how it ended

Two outcomes, via AskUserQuestion:

- **done** — the goal was reached
- **abandoned** — the goal was dropped (a better approach was found, requirements changed, it turned out unnecessary)

For **abandoned**, ask for a one-line reason and record it. Without it, the archived file leaves a future reader asking "why did this stop?" — which is exactly the context handoff exists to preserve.

If the user says neither really fits — the work is still live — stop and suggest `handoff:save` instead (see **Command notation**).

**If Remaining Next Steps was non-empty and the user picks done**, confirm once before moving on: point out what's still listed and ask them to reconsider — done anyway, abandoned instead, or stop and keep working (suggest `handoff:save`). This is a check, not a veto — if they confirm done, proceed without asking again. The point isn't to catch every mismatch, just the case where the record in front of them contradicts the choice they just made.

## 4. Seal it

Two edits, in this order:

**a. Record the status.** Insert a status line at the very top of the file, above the first heading, followed by a blank line:

```markdown
**Status**: done (2026-09-01)

# Goal
...
```

```markdown
**Status**: abandoned (2026-09-01) — GraphQL로 전환하기로 해서 REST 엔드포인트는 불필요

# Goal
...
```

Use today's date in `YYYY-MM-DD`. Keep the reason on the same line — the scan reads this line's first word as the status, so a multi-line reason would break it.

**b. Move it to the archive.**

```sh
mkdir -p "$(sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir done)"
mv "$dir/HANDOFF-<slug>.md" "$dir/done/HANDOFF-<slug>.md"
```

Sealing is the file's **location**, not a flag — that's why `resume` and `save` cannot pick a sealed handoff up by mistake. The status line is the human-readable record of why.

If a file of the same name already exists in `done/`, do **not** overwrite it. Report the collision and ask the user whether to keep both (suffix the new one with the date) or replace the old one.

## After sealing

Tell the user, in their language, with real values substituted — never the literal `<slug>` or `$HOME`:

1. The **full, expanded** archive path of the sealed file.
2. That it no longer appears in `handoff:list` or `handoff:resume`, and that `handoff:save` will start a **new** handoff rather than appending to this one.
3. That the file still exists — `handoff:delete` removes it for good if they want it gone.

## If the move fails

If the file can't be moved (permission denied, sandbox block, disk error), say so plainly — do not report success and do not fall back to a different path. State whether the status line was already written, so the user knows the file's actual state.

## Command notation

When you print a handoff command for the user, write it with the prefix **this host** uses to invoke skills — `/handoff:finish <slug>` on Claude Code, `$handoff:finish <slug>` on Codex. Never hardcode `/`: if the user typed the invocation that started this skill, copy its prefix; otherwise use this host's own.
