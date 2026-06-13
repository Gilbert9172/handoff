# handoff — Session Continuity Plugin for Claude Code

A Claude Code plugin that keeps your work context alive across sessions.
It captures "what you were trying to do, how far you got, and what to do next" as per-project personal notes — so the next conversation picks up exactly where you left off.

> This plugin is installed via the [Gilbert9172/handoff](https://github.com/Gilbert9172/handoff) marketplace. Follow the steps below.

---

## Why use it

- When a long conversation gets cut off or you return to a task days later, **you don't have to re-explain everything from scratch.**
- Logging "approaches that already failed" means the next session (or the next person) **won't repeat the same dead ends.**
- Notes are saved to your **home directory**, not the repository — no commit noise, no review overhead.

---

## Installation

### 1) Register the marketplace (once)

```shell
/plugin marketplace add https://github.com/Gilbert9172/handoff.git
```

This reads `.claude-plugin/marketplace.json` from the repo root and registers the `gilbert9172` marketplace.

### 2) Install the plugin

```shell
/plugin install handoff@gilbert9172
/reload-plugins          # apply to the current session immediately
```

Once installed, you'll have `/handoff:save`, `/handoff:list`, `/handoff:resume`, and `/handoff:delete`.

### 3) Verify

```shell
/handoff:list
```

"No handoffs yet for this project" on first run means everything is working.

> Want to be up and running in 5 minutes? Start with [QUICKSTART.en.md](./QUICKSTART.en.md).

### (Optional) Auto-install via project settings

Add the following to your project's `.claude/settings.json` to have the marketplace and plugin auto-registered whenever a session opens in that repo. Useful for sharing the same setup across multiple machines.

```json
{
  "extraKnownMarketplaces": {
    "gilbert9172": {
      "source": { "source": "url", "url": "https://github.com/Gilbert9172/handoff.git" }
    }
  },
  "enabledPlugins": {
    "handoff@gilbert9172": true
  }
}
```

---

## Commands

| Command | Purpose | Argument |
|---------|---------|----------|
| `/handoff:save [title]` | Save / update the current work as a handoff note | title (optional) |
| `/handoff:list` | List all handoffs for this project | — |
| `/handoff:resume [slug]` | Read a note and continue from its Next Steps | slug (optional) |
| `/handoff:delete [slug]` | Delete a finished or abandoned note | slug (optional) |

### `/handoff:save [title]`

Call this when wrapping up a session or switching to a different task.

- **With a title** — converts it to a slug (lowercase, spaces → `-`) and saves/updates that file.
- **Without a title** — scans existing handoffs: updates the file if it matches the current work, creates a new one (slug derived from the Goal) if it doesn't. Asks when ambiguous.
- After saving, prints the **full file path** and the resume command (`/handoff:resume <slug>`).

### `/handoff:list`

Displays all handoffs for this project in a table — **Slug · Updated · Goal**. Read-only; changes nothing.

### `/handoff:resume [slug]`

- **With a slug** — reads that note directly.
- **Without a slug** — auto-selects if there's only one; prompts you to choose if there are multiple; suggests `/handoff:save` if there are none.
- After reading the note, **briefly summarizes Goal · What Worked · Next Steps** to orient you, then **starts executing from Next Steps**. Approaches listed in **What Didn't Work** are not retried.

### `/handoff:delete [slug]`

- Deletion is **irreversible** — shows the slug and Goal for confirmation first.
- Without a slug, lets you select multiple notes to clean up in one go.

---

## Handoff document structure

Each note has five sections:

```markdown
# Goal
What you're trying to accomplish (one or two sentences)

# Current Progress
What has been done so far

# What Worked
Approaches that proved effective

# What Didn't Work
Approaches that were tried and failed (with reasons — prevents repetition)

# Next Steps
Concrete next actions
```

### Merge rules on update (`/handoff:save` applies these automatically)

- **Current Progress · Next Steps** → **overwritten** with the latest state
- **What Worked · What Didn't Work** → **accumulated** (past entries are never deleted)
- **Goal** → left unchanged unless the task itself has changed

---

## Where notes are stored

Handoffs are saved to your home directory, not the repository — the same location Claude Code uses for project memory:

```
~/.claude/projects/<project-slug>/handoffs/HANDOFF-<slug>.md
```

`<project-slug>` is the git root path with `/` replaced by `-` (falls back to the current directory if not in a git repo). Because it's based on the git root, handoffs are found correctly even when a session starts from a subdirectory.

Example — for a repo at `/Users/<you>/project/handoff`:

```
~/.claude/projects/-Users-<you>-project-handoff/handoffs/
├── HANDOFF-auth-jwt-migration.md
└── HANDOFF-pages-ci-setup.md
```

You can open and edit these files directly in your editor if needed.

---

## Example workflow

**First session — work, then wrap up**

```shell
/handoff:save auth-migration
```
```markdown
# Goal
Migrate session-based auth to JWT

# Current Progress
- Added JWT fields to user model
- Implemented token generation and verification functions

# What Worked
- Adopted the jsonwebtoken library

# What Didn't Work
- RSA keys were too operationally complex → switched to HS256

# Next Steps
- Write migration script to move existing sessions to JWT
- Update login/logout endpoints and run tests
```

**Next session — pick up right where you left off**

```shell
/handoff:list                    # confirm auth-migration is there
/handoff:resume auth-migration   # review Goal & Next Steps, then continue
# ... do the work ...
/handoff:save auth-migration     # update progress for the next session
# ... once done ...
/handoff:delete auth-migration   # clean up
```

---

## Best practices

**Do this**
- **Keep Goal clear** — the next session should understand the target at a glance.
- **Make Next Steps concrete** — "do more testing" ❌ → "write POST cases in `tests/auth.test.ts`" ✅
- **Log failures with reasons** — What Didn't Work is a time-saver for future sessions.
- **Clean up when done** — use `/handoff:delete` to keep the list tidy.

**Avoid**
- Progress entries so short the next session has to re-read the code.
- Letting old information linger — Progress and Next Steps should always reflect the current state.

---

## Management (update / remove)

```shell
/plugin marketplace update gilbert9172   # pull latest plugin changes
/plugin list                             # check installed plugins
/plugin disable handoff@gilbert9172      # temporarily disable
/plugin uninstall handoff@gilbert9172    # remove completely
```

After the plugin code is updated, run `/plugin marketplace update gilbert9172` then `/reload-plugins` to apply it.

---

## Troubleshooting

**Commands (`/handoff:*`) don't appear**
→ Check with `/plugin list` → run `/reload-plugins` → if still missing, verify the marketplace is registered with `/plugin marketplace list`.

**Handoffs not showing in list**
→ They may have been saved from a different git root. Run `git rev-parse --show-toplevel` to confirm the current root, then check that the matching slug folder exists under `~/.claude/projects/`.

**Save not working**
→ Verify you have write permission to `~/.claude/projects/`. The directory is created automatically on first save.

---

## How it works (internals)

All four commands share a single helper script (`scripts/handoffs.sh`) for consistent path resolution and scanning.

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir    # handoff directory for this project
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan   # per-note: slug · modified date · Goal paragraph
```

`${CLAUDE_PLUGIN_ROOT}` is injected automatically with the plugin's install path. `scan` reads the directory fresh every time — no index file means the list can never drift out of sync with the actual files.

---

## Improvements over the original

This plugin started from the [handoff skill in ykdojo/claude-code-tips](https://github.com/ykdojo/claude-code-tips/blob/main/skills/handoff/SKILL.md). The original was a single skill that wrote one `HANDOFF.md` to the repo root. Here's what was redesigned:

| | Original | This plugin |
|--|----------|------------|
| Form | Single skill (save only) | 4 commands (save · list · resume · delete) — full lifecycle |
| File | One fixed `HANDOFF.md` | Per-task `HANDOFF-<slug>.md` files |
| Storage | Repo root | `~/.claude/projects/<slug>/handoffs/` (home dir) |
| Scoping | cwd | git root slug |
| Listing | None | `scan` script (no index) |
| Distribution | Copy-paste | Marketplace register & install |
| Merge | "preserve existing" (one line) | Per-section rules (overwrite vs. accumulate) |

Three structural problems solved:

- **Single file breaks with parallel tasks.** Multiple tasks collide in one file. Per-slug files eliminate the ambiguity between "the default file," "a single task," and "an unnamed task."
- **Repo-root storage pollutes commits.** `HANDOFF.md` gets picked up by git, creating review friction and merge conflicts. Moving to the home directory makes the "personal session note" nature explicit.
- **cwd scoping loses notes in subdirectories.** Git-root slugging means a session opened from any subdirectory — including in a monorepo — still finds the right handoffs.

What was added that the original lacked:

- **resume** — reads the note and summarizes Goal · Next Steps before acting, so you confirm direction before execution. Approaches in **What Didn't Work** are never retried.
- **delete** — closes the lifecycle so notes don't pile up indefinitely.
- **No index** — `scan` rebuilds the list from disk every time, eliminating the class of sync bugs where an index and the actual files diverge.
