# handoff

A Claude Code plugin that keeps you from **losing your place as you switch between tasks**.
It captures "what you were trying to do, how far you got, and what to do next" as a per-task note — so whichever task you switch back to, you pick up right where you left off.

> This plugin is installed via the [Gilbert9172/handoff](https://github.com/Gilbert9172/handoff) marketplace. Follow the steps below.

---

## Why use it

- **Switch tasks and get back in fast** — each task keeps its own note, so `list` shows what's where at a glance and `resume` summarizes the Goal, What Worked, and Next Steps — dropping you back at your stopping point **without re-reading the code.**
- **Never repeat the same failure** — logging "approaches that already failed" means the next session (or the next person) **won't repeat the same dead ends.**
- **Cross session boundaries** — when a long conversation gets cut off or you return days later, **you don't have to re-explain everything from scratch.**
- **Personal notes, no commit worries** — notes live in your **home directory**, not the repository — no commit noise, no review overhead.

### How the parallelism works

The key is **one note per task**. Instead of cramming everything into a single `HANDOFF.md`, each task gets its own slugged file:

```
~/.claude/projects/<project>/handoffs/
├── HANDOFF-auction-state-machine.md
├── HANDOFF-batch-php-migration.md
└── HANDOFF-settlement-interface.md
```

So tasks never bleed into each other, and `/handoff:list` reads these files back one row at a time — **"what's where" becomes your dashboard.** Adding a task just adds one more file; existing notes are never touched.

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

Example — for a repo at `/Users/<you>/project/handoff`, the path resolves to:

```
~/.claude/projects/-Users-<you>-project-handoff/handoffs/HANDOFF-batch-php-migration.md
```

(Per-task notes pile up side by side in that folder — see [How the parallelism works](#how-the-parallelism-works) above.) You can open and edit these files directly in your editor if needed.

---

## Example workflow

**Several tasks in flight — see what's where at a glance**

```shell
/handoff:list
```

| Slug | Updated | Goal |
|------|---------|------|
| auction-state-machine | 2026-06-11 | Design the won→payment state transitions |
| batch-php-migration | 2026-06-13 | Migrate the legacy PHP batch jobs to the new runtime |
| settlement-interface | 2026-06-10 | Draft the settlement interface |

```shell
/handoff:resume batch-php-migration   # pick this one up today
```

`resume` summarizes that task's Goal, What Worked & Next Steps, skips the approaches in **What Didn't Work**, and continues right from where you stopped.

**One task's lifecycle — from save to cleanup**

```shell
/handoff:save batch-php-migration   # record progress before stepping away
```
```markdown
# Goal
Migrate the legacy PHP batch jobs to the new runtime

# Current Progress
- Settled the APP_ENV injection approach, moved the batch entrypoint

# What Worked
- Inject env vars at the container level (removes code-side branching)

# What Didn't Work
- Bundling a .env file → staging/prod value conflicts, abandoned

# Next Steps
- Map IAM permissions, then verify S3 access paths
- Wire up retry/alert paths for batch failures
```

```shell
/handoff:resume batch-php-migration   # continue in the next session
# ... do the work ...
/handoff:save batch-php-migration     # update progress
# ... once done ...
/handoff:delete batch-php-migration   # clean up
```

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

*Why* those structural differences (per-task files · home storage · git-root scoping) matter is covered above in [How the parallelism works](#how-the-parallelism-works) · [Where notes are stored](#where-notes-are-stored). On top of that, three things the original lacked:

- **resume** — reads the note, summarizes Goal · What Worked · Next Steps, then *stops before acting* for your confirmation (resuming loads context; it isn't sign-off on the plan).
- **delete** — closes the lifecycle so notes don't pile up indefinitely.
- **Index-less** — `scan` rebuilds the list from disk every time, eliminating the class of sync bugs where an index and the actual files diverge.
