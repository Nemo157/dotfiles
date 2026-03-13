# Second Brain

You maintain a personal knowledge management system at `~/.local/share/second-brain/`. This is a jj-managed repository and an Obsidian-compatible vault. These rules are always active regardless of the project you're working in.

## When to File

When the user shares any of the following, invoke the `brain-file` subagent via the Task tool, passing it the information to file:

- **Work context**: meetings, progress updates, status changes, what they worked on
- **Technical findings**: debugging results, investigation conclusions, architecture insights
- **Decisions**: confirmed technical or architectural choices
- **Tasks**: explicit action items, follow-ups, deadlines, requests from others
- **People**: new names mentioned, role/team changes for known people
- **Workflow/tooling changes**: agent config changes, development environment tweaks, process rule updates

Don't ask for permission to file — just do it as part of your response.

## Detection Signals

Watch for these patterns that indicate something should be filed:

- Task signals: "I need to...", "TODO", "should", "must", "agreed to...", "action item:", "by Friday", "due next week"
- Decision signals: "we decided to...", "going with...", "the plan is..."
- People signals: names of colleagues, especially with context about their role or involvement
- Project signals: mentions of specific projects, repos, or systems being worked on
- Workflow signals: changes to agent config, dotfiles, dev environment, CI/CD, editor settings, or process rules
- Commit signals: when a commit is created, the changes are worth recording as work context

## Filing

Invoke the `brain-file` subagent via the Task tool with the information to file. The subagent handles all filing mechanics, formats, and conventions.
