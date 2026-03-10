---
description: Show the task board from the second brain with status cross-referencing
---

Display the task board from the second brain, grouped by status with cross-references to external trackers.

## Workflow

### 1. Read All Tasks

```bash
ls ~/.local/share/second-brain/tasks/
```

Read every `.md` file in `tasks/` (except `index.md`). Parse the YAML frontmatter for `status`, `priority`, `due`, `linear`, and `github` fields.

### 2. Cross-Reference External Status

For tasks with external references, check current status:

**Linear:**
Use the `linear` agent to check the issue status:
> Get the status of issue <issue-id>

**GitHub:**
```bash
gh issue view <number> --repo <owner/repo> --json state,title 2>/dev/null || true
```

Flag discrepancies where the brain's status differs from the external source.

### 3. Display Task Board

Present tasks grouped by status, sorted by priority within each group:

```
## Active (N tasks)

### High Priority
- [ ] **Task Title** — brief description
  Due: YYYY-MM-DD | Linear: VEE-123 | [[projects/foo|foo]]

### Medium Priority
- [ ] **Task Title** — brief description
  [[projects/bar|bar]]

### Low Priority
- [ ] **Task Title** — brief description

## Blocked (N tasks)
- [ ] **Task Title** — reason for block
  Blocked since: YYYY-MM-DD

## Overdue
- [ ] **Task Title** — was due YYYY-MM-DD (N days ago)
  Linear: VEE-456 ⚠ Linear shows "completed" but brain shows "active"

## Recently Completed (last 7 days)
- [x] **Task Title** — completed YYYY-MM-DD
```

### 4. Flag Issues

After the task board, list any problems found:

- **Status mismatch**: Brain says active, external tracker says done (or vice versa)
- **Overdue**: Past due date and still active
- **Stale**: Active for 14+ days with no journal mentions in the last 7 days
- **Orphaned**: No project or external tracker reference

Ask if the user wants to update any flagged tasks.

### 5. Update if Requested

If the user asks to update tasks:

- Change YAML frontmatter `status` field
- Add a log entry with today's date
- Commit:

```bash
jj -R ~/.local/share/second-brain commit -m "update task statuses"
```

## Guidelines

- If there are no task files, say "No tasks tracked yet" and explain how to create one
- Don't read task files larger than expected — they should be short
- Present the board concisely; the user wants a quick overview, not full file contents
- Always show the overdue/flagged section even if the board is otherwise clean
