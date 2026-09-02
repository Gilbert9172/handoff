# handoff — Quick Start (5 minutes)

A plugin that keeps you from **losing your place as you switch between tasks**. For the full reference, see [README.en.md](./README.en.md).

---

## 1️⃣ Install (1 min)

```shell
/plugin marketplace add https://github.com/Gilbert9172/handoff.git
/plugin install handoff@gilbert9172
/reload-plugins
```

### Verify

```shell
/handoff:list      # "No handoffs yet" → you're good
```

---

## 2️⃣ First use (3 min)

```shell
# Do some work, then save before wrapping up
/handoff:save my-first-task

# Check what's saved
/handoff:list

# Open a new conversation later and pick up right here
/handoff:resume my-first-task
```

---

## 3️⃣ Daily pattern

🌅 **Starting a session** — run `/handoff:list` to see what's where at a glance.

| Slug | Updated | Lines | Goal |
|------|---------|-------|------|
| auction-state-machine | 2026-06-11 | 52 | Design the won→payment state transitions |
| batch-php-migration | 2026-06-13 | 88 | Migrate the legacy PHP batch jobs to the new runtime |

```shell
/handoff:resume batch-php-migration   # pick this one up today

# 🌙 Ending a session
/handoff:save              # without a title — auto-updates the matching note or creates a new one

# ✨ When a task is done
/handoff:finish batch-php-migration   # seal it into done/
```

A sealed note drops out of the list and `save` no longer appends to it. The record stays in `done/` — view it with `/handoff:list --done`, and use `/handoff:delete` only when you want it gone for good.

---

## 4️⃣ Commands at a glance

| Command | Purpose | Example |
|---------|---------|---------|
| `/handoff:save [title]` | Save / update current work | `/handoff:save api-docs` |
| `/handoff:save --compact` | Condense a long note (work continues) | `/handoff:save api-docs --compact` |
| `/handoff:list` | List all handoffs | `/handoff:list` |
| `/handoff:resume [slug]` | Resume a task | `/handoff:resume api-docs` |
| `/handoff:finish [slug]` | Seal finished work | `/handoff:finish api-docs` |
| `/handoff:delete [slug]` | Delete a note for good | `/handoff:delete api-docs` |

> Codex invokes skills with `$` — type `$handoff:save`, `$handoff:list`, and so on. This document uses Claude Code's `/` notation.

---

## 5️⃣ Note structure (sections filled on save)

```markdown
# Goal            ← what you're trying to accomplish (1–2 sentences)
# Current Progress ← what's been done so far
# What Worked      ← approaches that proved effective
# What Didn't Work ← failed approaches + reasons (prevents repetition)
# Next Steps       ← concrete next actions
```

> On update: **Progress · Next Steps are overwritten** with the latest state. **What Worked / Didn't Work accumulate** — past entries are never deleted.

---

## 6️⃣ Where notes live

```
~/.handoffs/<project-slug>/HANDOFF-<slug>.md
```

`<project-slug>` is the git root path with `/` replaced by `-`. Notes are scoped per project automatically, and the path is the same whether you save or read from Claude Code or Codex. You can open and edit these files directly.

---

## 7️⃣ FAQ

**Q. What if I don't provide a title?**
A. Scans existing handoffs — updates the matching note if the work is the same, or creates a new one (slug derived from the Goal) if it's new. Asks when ambiguous.

**Q. What if I save again with the same title?**
A. That file is updated: Progress and Next Steps are overwritten, What Worked / Didn't Work accumulate.

**Q. What if I switch projects?**
A. A different git root means a different slug, so each project's notes are kept separate automatically.

**Q. Can I recover a deleted note?**
A. No. You'll be asked for confirmation before deletion — choose carefully.

**Q. The commands aren't showing up.**
A. Run `/reload-plugins`. If they're still missing, check with `/plugin list` and `/plugin marketplace list`.

---

## Tips

- **Make Next Steps concrete.** "Do more testing" is vague; "`tests/auth.test.ts`, POST cases" tells your future self exactly where to start.
- **Log failures with reasons.** What Didn't Work is what prevents you from hitting the same wall twice.
- **Separate parallel tasks.** `/handoff:save auction-state-machine` and `/handoff:save batch-php-migration` keep things clean when you're juggling multiple tracks.

---

🚀 **One habit: run `/handoff:save` at the end of every session.**
