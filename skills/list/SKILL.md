---
name: list
description: List this project's handoff documents (personal session-continuity notes) with their goals and last-updated dates. Pass --done to list sealed ones instead. Use when the user wants to see what handoffs exist, can't remember a handoff's name, or is deciding which task to pick back up.
effort: low
disable-model-invocation: true
argument-hint: "[--done]"
allowed-tools:
  - Bash(sh:*), Bash(echo:*)
---

Run the shared scan script bundled with this plugin:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan        # active handoffs
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan done   # sealed archive (finish moves files here)
```

It prints one line per handoff, tab-separated: **slug, last-modified date, line count, status, and the first paragraph of its Goal section**. The script scopes to the current project — it derives the directory from the git root (fallback: cwd). (`${CLAUDE_PLUGIN_ROOT}` is this plugin's installation directory. If the variable is unavailable, the plugin root is two directories above this skill's base directory.)

- **Default** → list active handoffs. Their status is always `active`, so leave that column out: render **Slug | Updated | Lines | Goal**.
- **With `--done`** → list the sealed archive instead, and keep the status column, since `done` and `abandoned` are what distinguish those entries: render **Slug | Sealed | Status | Goal**.

Copy each Goal cell verbatim from the script's output; don't summarize, translate, or truncate it. Write the surrounding text — the header row and the hint — in the user's language. Then stop; listing is strictly read-only — don't create, rename, or modify anything.

After the table, add the hints that apply, each written with this host's command prefix (see **Command notation** below):

- Active listing → resume with `handoff:resume <slug>`, seal a finished one with `handoff:finish <slug>`. If any row exceeds 200 lines, note that `handoff:save <slug> --compact` condenses it.
- `--done` listing → remove permanently with `handoff:delete <slug>`.

Empty results:

- No active handoffs → say there are none for this project yet and that `handoff:save` creates one. If the archive is non-empty, mention that sealed ones are visible with `--done`.
- No sealed handoffs (with `--done`) → say the archive is empty.

## Command notation

When you print a handoff command for the user, write it with the prefix **this host** uses to invoke skills — `/handoff:resume <slug>` on Claude Code, `$handoff:resume <slug>` on Codex. Never hardcode `/`: if the user typed the invocation that started this skill, copy its prefix; otherwise use this host's own.
