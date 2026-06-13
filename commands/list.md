---
description: List this project's handoff documents (personal session-continuity notes) with their goals and last-updated dates. Use when the user wants to see what handoffs exist, can't remember a handoff's name, or is deciding which task to pick back up.
allowed-tools:
  - Bash(sh:*), Bash(echo:*)
---

Run the shared scan script bundled with this plugin:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan
```

It prints one line per handoff: slug, last-modified date, and the first paragraph of its Goal section (tab-separated). The script scopes to the current project — it derives the directory from the git root (fallback: cwd). (`${CLAUDE_PLUGIN_ROOT}` is this plugin's installation directory. If the variable is unavailable, the plugin root is two directories above this skill's base directory.)

Present the output as a table in the script's column order — **Slug | Updated | Goal** — followed by the hint: resume with `/handoff:resume <slug>`, delete with `/handoff:delete <slug>`. Then stop; listing is strictly read-only — don't create, rename, or modify anything.

- If the scan prints nothing, say there are no handoffs for this project yet and that `/handoff:save` creates one.
