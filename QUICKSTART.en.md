# handoff — Quick Start (5 minutes)

A plugin that keeps your work context alive across Claude Code sessions. For the full reference, see [README.en.md](./README.en.md).

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

```shell
# 🌅 Starting a session
/handoff:list              # see what's in progress
/handoff:resume auth       # resume by slug

# 🌙 Ending a session
/handoff:save              # without a title — auto-updates the matching note or creates a new one

# ✨ When a task is done
/handoff:delete auth       # clean up
```

---

## 4️⃣ Commands at a glance

| Command | Purpose | Example |
|---------|---------|---------|
| `/handoff:save [title]` | Save / update current work | `/handoff:save api-docs` |
| `/handoff:list` | List all handoffs | `/handoff:list` |
| `/handoff:resume [slug]` | Resume a task | `/handoff:resume api-docs` |
| `/handoff:delete [slug]` | Delete a note | `/handoff:delete api-docs` |

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
~/.claude/projects/<project-slug>/handoffs/HANDOFF-<slug>.md
```

`<project-slug>` is the git root path with `/` replaced by `-`. Notes are scoped per project automatically. You can open and edit these files directly.

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
- **Separate parallel tasks.** `/handoff:save frontend-refactor` and `/handoff:save backend-api` keep things clean when you're juggling multiple tracks.

---

🚀 **One habit: run `/handoff:save` at the end of every session.**
