---
name: delete
description: Permanently delete a handoff document — an active one that is no longer wanted, or a sealed one being cleared out of the archive. Use when the user wants to clean up or remove handoff files for good. To end a task without losing its record, finish seals it instead.
effort: low
disable-model-invocation: true
argument-hint: "[title]"
allowed-tools:
  - Bash(sh:*), Bash(echo:*)
---

Run the shared script bundled with this plugin to see what exists:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir         # the handoff directory
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir done     # the sealed archive
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan         # active: slug, updated, lines, status, first Goal paragraph
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan done    # sealed archive, same columns
```

(`${CLAUDE_PLUGIN_ROOT}` is this plugin's installation directory. If the variable is unavailable, the plugin root is two directories above this skill's base directory.)

Deletion is permanent, so scan **both** areas and be explicit about which one a file is in — removing an active handoff throws away work someone may still be counting on, while clearing the archive only discards a record of finished work.

- **With a title argument** → look for `$dir/HANDOFF-<title-slug>.md` first, then `$dir/done/HANDOFF-<title-slug>.md` (title lowercased, spaces → hyphens). If neither exists, show both scans so the user can pick the right slug.
- **Without a title** → show both tables, labelled, and ask which to delete via AskUserQuestion (multiSelect, since cleanup often covers several finished tasks).

Deletion is unrecoverable and the file is the user's own note, so confirm before removing: show each chosen handoff's slug, area (active or sealed) and Goal line and ask for confirmation via AskUserQuestion — unless the user already named the exact handoff in this same request AND its Goal clearly matches what they described.

If the user is deleting an **active** handoff because its task is over, mention once that `handoff:finish <slug>` (see **Command notation**) seals it while keeping the record. Mention it, then do what they asked.

Then `rm` the confirmed files and report exactly which paths were removed.

## Command notation

When you print a handoff command for the user, write it with the prefix **this host** uses to invoke skills — `/handoff:finish <slug>` on Claude Code, `$handoff:finish <slug>` on Codex. Never hardcode `/`: if the user typed the invocation that started this skill, copy its prefix; otherwise use this host's own.
