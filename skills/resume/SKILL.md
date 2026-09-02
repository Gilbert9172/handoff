---
name: resume
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
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan  # slug, updated, lines, status, first Goal paragraph
```

(`${CLAUDE_PLUGIN_ROOT}` is this plugin's installation directory. If the variable is unavailable, the plugin root is two directories above this skill's base directory.)

`scan` lists only **active** handoffs. Ones sealed by `finish` live under `done/` and are deliberately out of scope — their work is over, so they are not resume candidates.

- **With a title argument** → the file is `$dir/HANDOFF-<title-slug>.md` (title lowercased, spaces → hyphens). If it doesn't exist, show the scan results so the user can pick the right slug. If it exists only under `done/`, say it was sealed and show its Status line rather than resuming it — reopening a sealed handoff is not this skill's call.
- **Without a title** → if exactly one handoff exists, use it; if several, show the table and ask which via AskUserQuestion; if none, say so and suggest `handoff:save` (see **Command notation**) to create one.

## Continue the work

1. Read the chosen file in full.
2. Restate the **Goal**, **What Worked** and **Next Steps** to the user in a couple of sentences, so they can correct course before you invest effort. Respond in the user's language.
3. Ask whether to proceed with the **Next Steps**, then **stop and wait** for the user's answer
  - Don't execute in the same turn. Resuming loads context — it doesn't commit the user to the plan; they may tweak the steps or do something else.
  - Prefer AskUserQuestion when the choice is clear-cut (e.g. "Continue with the next steps" vs. "Do something else").
4. Once the user confirms, execute the **Next Steps**. Respect **What Didn't Work** — the whole point of that section is that failed approaches aren't repeated.

## When the work reaches a stopping point

Sessions end in one of three ways, and the user needs to know which command matches which. When the work winds down — the Next Steps are through, or the session is wrapping up — say which applies, in one line, in the user's language:

| Situation | Command |
|---|---|
| More to do later | `handoff:save <slug>` — update this handoff |
| Completely finished, or dropping it | `handoff:finish <slug>` — seal it |
| The Goal itself changed | `handoff:save` — start a new handoff for the new work |

Two rules about this:

- **Mention, don't ask.** Don't stop the user with a question about which one they want. State the options and let them choose; they may well want to keep working.
- **Never seal anything yourself.** Running out of Next Steps is not proof the work is over — plans go stale, and the user may have taken the task somewhere the document doesn't reflect yet. Only the user runs `finish`.

## Command notation

When you print a handoff command for the user, write it with the prefix **this host** uses to invoke skills — `/handoff:resume <slug>` on Claude Code, `$handoff:resume <slug>` on Codex. Never hardcode `/`: if the user typed the invocation that started this skill, copy its prefix; otherwise use this host's own.
