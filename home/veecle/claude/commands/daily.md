---
description: Morning standup — recap last working day, in-progress items, and today's todos
agent: brain
---

Generate a daily standup summary from the second brain at `~/.local/share/second-brain/`.

## Steps

1. **Find the last working day with a journal entry**: Use `date` to find today's date, then walk backwards from yesterday (or Friday if today is Monday) looking for a journal entry. Check each candidate date:
   ```bash
   ls ~/.local/share/second-brain/journal/daily/
   ```
   Skip weekends (Saturday/Sunday) and keep going back until you find a day that has an entry. This handles holidays and days off automatically. Search up to 14 days back; if nothing is found, say so.

2. **Read that journal entry**:
   ```bash
   cat ~/.local/share/second-brain/journal/daily/YYYY-MM-DD.md
   ```
   Summarize what was worked on. Note the date in the heading so it's clear if it was more than one day ago.

3. **Read today's journal entry** (if it exists) for any already-filed notes.

4. **Read all task files**:
   ```bash
   ls ~/.local/share/second-brain/tasks/
   ```
   Read each `.md` file and parse the YAML frontmatter for `status`, `priority`, and `due` fields.

5. **Present the standup**:

   ### What I worked on (last working day)
   Bullet-point summary of the journal entry from the last working day — projects touched, PRs, meetings, findings.

   ### Still in progress
   Tasks with `status: active` that were mentioned in the last working day's journal entry. Include their priority and any linked issues.

   ### Today's todos
   - Overdue tasks (past `due` date, still active) — flag these first
   - Tasks due today
   - Active high-priority tasks
   - Active medium-priority tasks with upcoming due dates

## Guidelines

- Keep it concise — this is a quick morning overview, not a full recap
- If there are no tasks or journal entries, say so plainly instead of showing empty sections
