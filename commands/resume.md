---
description: Resume work from a handoff document — read it and continue executing its Next Steps. Use at the start of a fresh conversation to pick up where a previous one left off, or whenever the user says to continue/resume an earlier task that has a handoff.
argument-hint: "[title]"
allowed-tools:
  - Bash(sh:*), Bash(echo:*)
---

A handoff document was written by a previous conversation precisely so that you — an agent with fresh context — can continue the work without re-discovering everything. Your job is to load that context and keep going.

## Pick the handoff

Run the shared script bundled with this plugin to see what exists:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir   # the handoff directory
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan  # slug, updated date, first Goal paragraph per handoff
```

(`${CLAUDE_PLUGIN_ROOT}` is this plugin's installation directory. If the variable is unavailable, the plugin root is two directories above this skill's base directory.)

- **With a title argument** → the file is `$dir/HANDOFF-<title-slug>.md` (title lowercased, spaces → hyphens). If it doesn't exist, show the scan results so the user can pick the right slug.
- **Without a title** → if exactly one handoff exists, use it; if several, show the table and ask which via AskUserQuestion; if none, say so and suggest `/handoff:save` to create one.

## Continue the work

1. Read the chosen file in full.
2. Restate the **Goal**, **What Worked** and **Next Steps** to the user in a couple of sentences, so they can correct course before you invest effort. Respond in the user's language.
3. Ask whether to proceed with the **Next Steps**, then **stop and wait** for the user's answer
  - Don't execute in the same turn. Resuming loads context — it doesn't commit the user to the plan; they may tweak the steps or do something else.
  - Prefer AskUserQuestion when the choice is clear-cut (e.g. "Continue with the next steps" vs. "Do something else").
4. Once the user confirms, execute the **Next Steps**. Respect **What Didn't Work** — the whole point of that section is that failed approaches aren't repeated.
5. When this session later wraps up, update the same handoff via `/handoff:save` so the chain continues.
