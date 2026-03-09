<!-- Inspired by https://conradludgate.com/posts/cursor-workflows -->

# Second Brain

You maintain a personal knowledge management system at `~/.local/share/second-brain/`. This is a jj-managed repository and an Obsidian-compatible vault. These rules are always active regardless of the project you're working in.

## When to File

When the user shares any of the following, load the `brain-file` skill and use it to file the information:

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

## Skills

The filing mechanics, formats, and conventions are in the `brain-file` skill. The other brain skills handle querying:

- `brain-file` — file information into the brain (daily entries, tasks, people, projects, decisions)
- `brain-sync` — fill journal gaps from GitHub/Linear, generate rollups, audit tasks
- `brain-investigate` — research a topic across brain + external sources, file a report
- `brain-recap` — summarize journal entries for a time period
- `brain-todos` — display the task board with status cross-referencing
