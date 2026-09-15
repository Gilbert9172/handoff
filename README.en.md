# handoff

A plugin for **handing work between Claude Code and Codex agents and preserving context across long-running tasks**.
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
~/.handoffs/<project>/
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

Once installed, you'll have `/handoff:save`, `/handoff:list`, `/handoff:resume`, `/handoff:finish`, and `/handoff:delete`.

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

| Command | Purpose | Arguments |
|---------|---------|-----------|
| `/handoff:save [title] [--compact]` | Save / update the current work as a handoff note | title (optional), `--compact` (optional) |
| `/handoff:list [--done]` | List handoffs for this project | `--done` (optional) |
| `/handoff:resume [slug]` | Read a note and continue from its Next Steps | slug (optional) |
| `/handoff:finish [slug]` | Seal a note whose work is over | slug (optional) |
| `/handoff:delete [slug]` | Delete a note permanently | slug (optional) |

> **On Codex the prefix is `$`.** Codex invokes skills with `$`, so type `$handoff:save`, `$handoff:list`, `$handoff:resume`, `$handoff:finish`, `$handoff:delete` there. The rest of this document uses Claude Code's `/` notation.

### The life of a note

```
save ──▶ (working: resume/save repeatedly) ──▶ finish ──▶ archived in done/
                                                            └──▶ delete (gone for good)
```

`finish` **declares the work over**; `delete` **removes the file**. A finished note stays in `done/` as a record — it just drops out of `list` and `resume`.

### `/handoff:save [title] [--compact]`

Records progress when you're wrapping up a session or switching tasks.

- **With a title**, it slugifies it (lowercase, spaces → `-`) and saves/updates that file.
- **Without one**, it scans existing handoffs: same work → update that file; new work → derive a slug from the Goal and create one. If it's genuinely unclear, it asks.
- **It never appends to a sealed note.** If work resumes on a finished task, that's new work and gets a new note.
- After saving, prints the **full file path** and the resume command (`/handoff:resume <slug>`).
- If the document passes **200 lines**, it offers to condense it — without blocking the save.

**`--compact`** — condenses accumulated history. The work continues, so it stays **conservative**: older What Worked / What Didn't Work entries collapse to one line each, while recent entries, Goal, Current Progress and Next Steps are left alone. Failed approaches are never dropped entirely — losing them means repeating them.

A related follow-up note records its **predecessor’s exact path, inherited decisions or constraints, and new scope** in Current Progress. Sealed predecessors remain unchanged.

Compacting is **not** sealing. The note stays live; ending it is `finish`.

### `/handoff:list [--done]`

Shows this project's active handoffs as a table — **Slug · Updated · Lines · Goal**. Strictly read-only.

- **`--done`** — lists sealed notes instead (**Slug · Sealed · Status · Goal**).

### `/handoff:resume [slug]`

- **With a slug**, reads that note; if it doesn't exist, shows the list.
- **Without a slug** — auto-selects if there's only one; prompts you to choose if there are multiple; suggests `/handoff:save` if there are none.
- Reads the whole note, checks relevant predecessor references and the actual working state, and **summarizes Goal · What Worked · Next Steps**. Proceeds when execution is already authorized; otherwise asks before executing. Approaches listed under **What Didn't Work** are not repeated under the same conditions, and items under **Parked** are outside the Goal, so they aren't done either.
- An empty Next Steps list does not prove completion. It suggests `finish` only when recorded results support the Goal’s completion criteria; otherwise it reports unknowns or waiting conditions.
- Sealed notes are excluded from the candidates.
- When the work reaches a stopping point, it names the next command in one line — `save` if there's more to do, `finish` if it's completely over, a new note if the Goal itself changed. It tells you; it doesn't block you with a question.

### `/handoff:finish [slug]`

Seals a note once its work is genuinely over.

- Before showing anything, refreshes **Current Progress** from this session and auto-compacts past 200 lines, the same way `--compact` would. Each Next Steps item is annotated as completed, unfinished, or dropped based on actual results; unknown outcomes stay explicit.
- Shows **Goal · Current Progress · remaining Next Steps · Parked**, then asks how it ended. Parked items were set aside on purpose, so they don't count against sealing; after sealing, any of them can start a new note — **done** (goal reached) or **abandoned** (dropped, with a one-line reason). If unfinished or unknown Next Steps remain and you pick done, it confirms once before proceeding (not a refusal — just a check).
- Writes a line like `**Status**: done (2026-09-01)` at the top of the document and moves it to `done/`.
- Once sealed it no longer appears in `list` or `resume`, and `save` won't append to it. The file itself stays.

> **You decide when it's over.** Leftover Next Steps don't block sealing — you may have changed direction mid-task, which makes the old plan obsolete rather than unfinished. The skill points out what's left, confirms once if that contradicts your choice, and never decides for you. It is **never invoked automatically.**

### `/handoff:delete [slug]`

- Deletion is **irreversible**, so it shows the slug, location (active / sealed) and Goal, and asks for confirmation first.
- Without a slug it shows both active and sealed notes so you can clear several at once.
- To end a task while keeping its record, use `/handoff:finish` instead.

---

## Automatic save reminders (context hook)

So `/handoff:save` doesn't rely on memory alone, installing the plugin also registers a **UserPromptSubmit hook**. On every message it reads the **actual context usage** from the session transcript and signals in three stages:

| Tag | Threshold (default) | Behavior |
|-----|---------------------|----------|
| 🟢 | **35%** | Gently recommends using `/handoff:save` |
| 🟠 | **50%** | Clearly recommends running `/handoff:save` |
| 🔴 | **75%** | Warns that context is running low and strongly advises using `/handoff:save` to manage it |

- **Nothing is saved automatically.** All three stages only suggest — an actual save happens only when you run `/handoff:save`.
- Each stage fires **once per session**; if several stages are crossed at once, only the highest one fires.
- Works the same **even with auto-compact turned off** — you get a chance to save before context runs out and the working state is lost.

Thresholds are configurable via environment variables:

| Variable | Default | Meaning |
|----------|---------|---------|
| `HANDOFF_BAND_1` | `35` | 🟢 stage 1 usage (%) |
| `HANDOFF_BAND_2` | `50` | 🟠 stage 2 usage (%) |
| `HANDOFF_BAND_3` | `75` | 🔴 stage 3 usage (%) |
| `HANDOFF_CONTEXT_LIMIT` | detected by model | Override for this session's context window size (tokens) |
| `HANDOFF_CMD_PREFIX` | auto-detected (`/` or `$`) | Command prefix used in the hook's message. Auto-detected from the transcript shape (Claude Code → `/`, Codex → `$`); set this to override the detected value |

> For Claude, the hook reads the model from assistant messages in the transcript, uses 200,000 for Haiku 4.5, and uses 1,000,000 for every other model (including newly introduced, not-yet-known models). For Codex, it uses the transcript's `model_context_window`. Set `HANDOFF_CONTEXT_LIMIT` explicitly only when automatic detection does not fit a custom deployment.

---

## Handoff document structure

Each note has six sections. Where relevant, preserve user constraints, actual working locations and files, decisions and reasons, verification evidence versus unverified work, blockers and resume conditions. For code, include the branch/worktree and uncommitted changes needed to locate the work:

```markdown
# Goal
What is true when the work is over — an end state, not an activity (one or two sentences)

# Current Progress
What has been done so far

# What Worked
Approaches that proved effective

# What Didn't Work
Approaches that were tried and failed (with reasons — prevents repetition)

# Next Steps
Only what the Goal still requires

# Parked
Worth doing, but not required by this Goal (with a word on why it was set aside)
```

### How a note gets an end point

If every idea that comes up lands in Next Steps, a note never ends. So `save` asks one question per item — **"if this is never done, is the Goal still reached?"** No → Next Steps; yes → Parked. That's why the Goal is written as an end state rather than an activity: it's what makes that judgment possible.

**Recorded results supporting the Goal’s completion criteria, with no required work remaining**, are the basis for suggesting `finish`. An empty list alone is not evidence of completion. Any Parked item can start a new note. Sealing is still yours to do.

### Merge rules on update (`/handoff:save` applies these automatically)

- **Current Progress · Next Steps** → **overwritten** with the latest state
- **What Worked · What Didn't Work · Parked** → distinct findings **accumulate**; repeated facts merge without losing evidence or conditions. Superseded conclusions retain the reason and a reference to their replacement
- **Goal** → sharpened as the end state becomes clearer, otherwise left unchanged unless the task itself has changed

When a note grows long, `/handoff:save --compact` collapses only the older entries. Failed approaches are kept either way.

---

## Where notes are stored

Handoffs are saved to your home directory, not the repository. Automatic sharing requires the same home directory and absolute project path on a local machine; other devices or checkouts are not automatically synchronized. The path is host-neutral, so Claude Code and Codex resolve to the same location:

```
~/.handoffs/<project-slug>/HANDOFF-<slug>.md        # active
~/.handoffs/<project-slug>/done/HANDOFF-<slug>.md   # sealed by finish
```

`<project-slug>` is the git root path with `/` replaced by `-` (falls back to the current directory if not in a git repo). Because it's based on the git root, handoffs are found correctly even when a session starts from a subdirectory — and because both hosts compute the same slug from the same repo path, saving from one and resuming from the other lands in the same folder.

Example — for a repo at `/Users/<you>/project/handoff`, the path resolves to:

```
~/.handoffs/-Users-<you>-project-handoff/HANDOFF-batch-php-migration.md
```

(Per-task notes pile up side by side in that folder — see [How the parallelism works](#how-the-parallelism-works) above.) You can open and edit these files directly in your editor if needed.

**If handoffs saved with an older version of this plugin aren't showing up**, they're likely still at the old location, `~/.claude/projects/<slug>/handoffs/`. Run `/handoff:migrate` to move the old documents for the same project (same slug) to the path above — it won't find them if the repo itself was moved to a different absolute path, since that changes the slug; move those by hand instead. This command is a temporary transition aid and may be removed in a later version.

---

## Example workflow

**Several tasks in flight — see what's where at a glance**

```shell
/handoff:list
```

| Slug | Updated | Lines | Goal |
|------|---------|-------|------|
| auction-state-machine | 2026-06-11 | 52 | Design the won→payment state transitions |
| batch-php-migration | 2026-06-13 | 88 | Migrate the legacy PHP batch jobs to the new runtime |
| settlement-interface | 2026-06-10 | 34 | Draft the settlement interface |

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
→ They may have been saved from a different git root. Run `git rev-parse --show-toplevel` to confirm the current root, then check that the matching slug folder exists under `~/.handoffs/`.

**Save not working**
→ Verify you have write permission to `~/.handoffs/`. The directory is created automatically on first save.

---

## How it works (internals)

All commands share a single helper script (`scripts/handoffs.sh`) for consistent path resolution and scanning.

```sh
sh "${HANDOFF_PLUGIN_ROOT}/scripts/handoffs.sh" dir         # handoff directory for this project
sh "${HANDOFF_PLUGIN_ROOT}/scripts/handoffs.sh" dir done    # archive directory for sealed notes
sh "${HANDOFF_PLUGIN_ROOT}/scripts/handoffs.sh" scan        # per active note: slug · modified · lines · status · Goal paragraph
sh "${HANDOFF_PLUGIN_ROOT}/scripts/handoffs.sh" scan done   # sealed notes, same columns
```

Before running these examples, set `HANDOFF_PLUGIN_ROOT` to the plugin installation path, two directories above the skill directory. Hook configuration uses the host-provided root variable. `scan` reads the directory fresh every time — no index file means the list can never drift out of sync with the actual files.

---

## Improvements over the original

This plugin started from the [handoff skill in ykdojo/claude-code-tips](https://github.com/ykdojo/claude-code-tips/blob/main/skills/handoff/SKILL.md). The original was a single skill that wrote one `HANDOFF.md` to the repo root. Here's what was redesigned:

| | Original | This plugin |
|--|----------|------------|
| Form | Single skill (save only) | 5 commands (save · list · resume · finish · delete) — full lifecycle |
| File | One fixed `HANDOFF.md` | Per-task `HANDOFF-<slug>.md` files |
| Storage | Repo root | `~/.handoffs/<slug>/` (home dir, host-neutral) |
| Scoping | cwd | git root slug |
| Listing | None | `scan` script (no index) |
| Distribution | Copy-paste | Marketplace register & install |
| Merge | "preserve existing" (one line) | Per-section rules (overwrite vs. accumulate) |

*Why* those structural differences (per-task files · home storage · git-root scoping) matter is covered above in [How the parallelism works](#how-the-parallelism-works) · [Where notes are stored](#where-notes-are-stored). On top of that, three things the original lacked:

- **resume** — reads the note, summarizes Goal · What Worked · Next Steps, then *stops before acting* for your confirmation (resuming loads context; it isn't sign-off on the plan).
- **finish** — seals finished work and closes the lifecycle. This is what stops notes from growing without bound: a sealed note is never appended to, so the next task naturally becomes a new note. Whether the work is over is always the user's call — other commands mention `finish`, they never decide for you.
- **delete** — removes files for good, once you want even the archived record gone.
- **Index-less** — `scan` rebuilds the list from disk every time, eliminating the class of sync bugs where an index and the actual files diverge.
