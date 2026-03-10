---
name: brain-file
description: >
  File information into the second brain — daily journal entries, tasks,
  people, projects, and decision records
---

File information into the second brain at `~/.local/share/second-brain/`.

## Directory Structure

```
~/.local/share/second-brain/
├── journal/
│   ├── daily/        # YYYY-MM-DD.md — timestamped work log
│   ├── weekly/       # YYYY-Www.md — weekly rollup
│   ├── monthly/      # YYYY-MM.md — monthly rollup
│   └── yearly/       # YYYY.md — yearly rollup
├── tasks/
│   ├── index.md      # Task board overview (auto-generated)
│   └── <slug>.md     # Individual task files
├── projects/
│   └── <name>.md        # Project overview
├── people/
│   ├── <name>.md          # Non-developer people (kebab-case)
│   └── @<handle>.md       # Developers (GitHub handle with @ prefix)
├── reports/
│   └── <slug>.md     # Investigation write-ups
└── decisions/
    └── <slug>.md     # Decision records
```

## Daily Journal Entries

Create or append to today's daily note at `journal/daily/YYYY-MM-DD.md`:

- Timestamp each entry as `### HH:MM` (24-hour format, local time)
- Write a concise summary of what was shared
- Use `[[wiki-links]]` to reference related projects, tasks, people, decisions
- Add relevant `#tags` at the end of the entry
- Link format: `[[projects/<name>|Project Name]]`, `[[people/@handle|Name]]` or `[[people/<name>|Name]]`, `[[tasks/<slug>|Task Title]]`

Example:

```markdown
### 14:32

Working on [[projects/dotfiles|dotfiles]] — designing second-brain system
for Claude/OpenCode integration. Reviewed Conrad Ludgate's blog post on Cursor workflows.

#design #tooling
```

## Task Files

When tasks are detected, prompt: "I noticed a potential task: <description>. Want me to track it?" If confirmed, create `tasks/<slug>.md`:

```markdown
---
status: active
priority: medium
due: YYYY-MM-DD
linear: VEE-1234
github: owner/repo#123
---

## Task title

Description of what needs to be done.

## Related
- [[projects/<name>|Project Name]]
- [[people/<name>|Name]]

## Log
- YYYY-MM-DD: Created from daily note
```

Valid statuses: `active`, `blocked`, `done`, `cancelled`
Valid priorities: `high`, `medium`, `low`
The `linear`, `github`, and `due` fields are optional — only include when relevant.

## People Files

When a person is mentioned:

1. If no file exists, ask: "I don't have a file for <Name>. Want me to create one? What's their role/team?"
2. If a file exists and the conversation reveals new information, append to their notes

**Filename convention:**
- Developers use their GitHub handle with `@` prefix: `people/@handle.md`
- Non-developers use kebab-case real names: `people/first-last.md`
- When unsure if someone is a developer, ask

**Link format:**
- Developers: `[[people/@handle|Display Name]]`
- Non-developers: `[[people/first-last|Display Name]]`

Format (`people/@handle.md` or `people/<name>.md`):

```markdown
- **Name**: Full Name
- **Role**: Their role
- **Team**: Their team

## Notes

- YYYY-MM-DD: Context about this person
```

## Project Overviews

When project information surfaces (architecture decisions, status changes, blockers, milestones):

- If the project has an overview file, update it
- If no overview exists and the project is mentioned repeatedly, suggest creating one

Format (`projects/<name>.md`):

```markdown
Brief description of the project.

## Status
Current status summary.

## Key Decisions
- YYYY-MM-DD: [[decisions/<slug>|Decision description]]

## Related
- [[people/<name>|Name]] — role in project
- Repository: `owner/repo`
- Linear project: <project-id>
```

## Decision Records

When a technical decision is discussed and confirmed, offer to file a decision record at `decisions/<slug>.md`:

```markdown
---
date: YYYY-MM-DD
status: accepted
---

## Decision Title

## Context
What prompted this decision.

## Decision
What was decided.

## Consequences
Expected impact.

## Related
- [[projects/<name>|Project Name]]
```

## Commit Protocol

After filing, commit changes:

```bash
jj -R ~/.local/share/second-brain commit -m "<summary>"
```

Keep messages short: "daily entry for 2026-03-06", "add task: implement caching", "update Alice's people file".

## Conventions

- **Slugs**: lowercase kebab-case (`connection-pooling`, `alice-smith`); developers use `@github-handle` instead
- **Wiki-links**: Obsidian-style `[[path|display text]]`
- **Timestamps**: 24-hour `HH:MM` for journal entries
- **Dates**: `YYYY-MM-DD` everywhere
- **Tags**: lowercase `#tag`, hyphens for spaces (`#code-review`)
- **Directories**: `mkdir -p` before writing to new paths
- **Idempotency**: check if today's daily note exists; append if it does
- **Cross-referencing**: when creating a task from a daily entry, link both directions
- **Source provenance**: rollups and recaps must include a `## Sources` section with wiki-links to the documents they summarize (e.g., weekly rollups link to daily entries, monthly rollups link to weekly rollups)
- **Graph connectivity**: use `[[wiki-links]]` for project/repo references everywhere (not backtick code spans) so nodes connect in the graph view
- **Graph display names**: use filenames that are meaningful on their own (e.g., `projects/<name>.md` not `projects/<name>/overview.md`) so graph nodes display useful labels
- **No H1 headings**: Obsidian uses the filename as the page title, so files should not include a top-level `#` heading. Use `##` as the highest heading level. For files with opaque filenames (e.g., `DEV-1512.md`), put the human-readable title as the first `##` heading
