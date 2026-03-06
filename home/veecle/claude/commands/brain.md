---
description: Interact with your second brain — file notes, sync, investigate, recap, or check tasks
---

You are interacting with the user's second brain at `~/.local/share/second-brain/`.

Based on the user's input after `/brain`, determine the appropriate action:

## Routing

- **"sync"** — Load the `brain-sync` skill and run the sync workflow
- **"investigate <topic>"** or **"research <topic>"** — Load the `brain-investigate` skill for the given topic
- **"recap"**, **"this week"**, **"last week"**, **"this month"** — Load the `brain-recap` skill for the specified period
- **"todos"**, **"tasks"**, **"board"** — Load the `brain-todos` skill to show the task board
- **"file <text>"** or **"log <text>"** — File the provided text as a timestamped entry in today's daily note, following the second-brain import rules for wiki-links, tags, and cross-referencing
- **Anything else** — Treat as free-form information to file in today's daily note

## Filing Inline

When filing directly (not dispatching to a skill), follow the always-on second-brain rules:

1. Create/append to `~/.local/share/second-brain/journal/daily/YYYY-MM-DD.md`
2. Add a `### HH:MM` timestamped entry
3. Use `[[wiki-links]]` for cross-references
4. Detect and prompt for tasks
5. Commit: `jj -R ~/.local/share/second-brain commit -m "daily entry for YYYY-MM-DD"`
