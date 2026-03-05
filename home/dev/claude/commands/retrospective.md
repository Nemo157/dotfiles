---
description: Review logged problems and propose config improvements
---

Review the problems log and propose improvements to avoid them in future sessions.

## Steps

1. Read the problems log at `~/.local/share/opencode/problems.md`
2. Read the current global rules at `~/.config/opencode/AGENTS.md`
3. If there is a project-level `AGENTS.md` in the current directory, read that too
4. Group the logged problems by theme (e.g. wrong tool used, missing permission, bad assumption, missing rule)
5. For each group, propose a concrete fix — either:
   - A rule addition/change to the global config (note: global config lives in the dotfiles repo at `home/dev/claude/CLAUDE.md`)
   - A permission change (in `home/dev/claude/default.nix`)
   - A project-local `AGENTS.md` addition
6. Present the grouped problems with your proposed fixes
7. Ask which changes to apply, then ask whether to clear the reviewed entries from the log
