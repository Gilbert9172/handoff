---
description: Delete a handoff document that is no longer needed, e.g. when its task is finished or abandoned. Use when the user wants to clean up or remove a handoff.
argument-hint: "[title]"
allowed-tools:
  - Bash(sh:*), Bash(echo:*)
---

Run the shared script bundled with this plugin to see what exists:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir   # the handoff directory
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan  # slug, updated date, first Goal paragraph per handoff
```

(`${CLAUDE_PLUGIN_ROOT}` is this plugin's installation directory. If the variable is unavailable, the plugin root is two directories above this skill's base directory.)

- **With a title argument** → the file is `$dir/HANDOFF-<title-slug>.md` (title lowercased, spaces → hyphens). If it doesn't exist, show the scan results so the user can pick the right slug.
- **Without a title** → show the table and ask which to delete via AskUserQuestion (multiSelect, since cleanup often covers several finished tasks).

Deletion is unrecoverable and the file is the user's own note, so confirm before removing: show each chosen handoff's slug and Goal line and ask for confirmation via AskUserQuestion — unless the user already named the exact handoff in this same request AND its Goal clearly matches what they described.

Then `rm` the confirmed files and report exactly which paths were removed.
