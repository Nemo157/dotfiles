# Linear CLI Skill

Use the `linear` CLI tool to query Linear data when you need to retrieve issues, teams, or project information.

## When to Use This Skill

Use the `linear` CLI tool when:
- You need to view issue details
- You need to list issues with specific filters (state, assignee, team)
- You need to get team or project information
- You need to view issue comments
- The user explicitly asks to use the Linear CLI

**Do NOT use this skill for:**
- Modifying issues, teams, or projects (ask user)
- Creating new issues or projects
- Deleting or updating Linear data

## Available Commands

### Issue Commands

**List issues:**
```bash
linear issue list [options]
```
Options:
- `--state <state>` - Filter by state (triage, backlog, unstarted, started, completed, canceled). Can be repeated. Default: unstarted
- `--all-states` - Show issues from all states
- `--assignee <username>` - Filter by assignee username
- `-A, --all-assignees` - Show issues for all assignees
- `-U, --unassigned` - Show only unassigned issues
- `--sort <sort>` - Sort order: manual or priority
- `--team <team>` - Team to list issues for
- `--no-pager` - Disable automatic paging

**View issue details:**
```bash
linear issue view [issueId]
```
If `issueId` is omitted, uses the issue from the current git branch.
Options:
- `--no-comments` - Exclude comments from output
- `--no-pager` - Disable automatic paging

**Get issue ID from branch:**
```bash
linear issue id
```
Prints the issue ID based on the current git branch.

**Get issue title:**
```bash
linear issue title [issueId]
```

**Get issue URL:**
```bash
linear issue url [issueId]
```

**Get issue description with trailer:**
```bash
linear issue describe [issueId]
```
Prints the issue title and Linear-issue trailer (useful for commit messages).

### Team Commands

**List teams:**
```bash
linear team list
```

**Get configured team ID:**
```bash
linear team id
```

**List team members:**
```bash
linear team members [teamKey]
```
Options:
- `-a, --all` - Include inactive members

### Project Commands

**List projects:**
```bash
linear project list [options]
```
Options:
- `--team <team>` - Filter by team key
- `--all-teams` - Show projects from all teams
- `--status <status>` - Filter by status name

**View project details:**
```bash
linear project view <projectId>
```

## Usage Patterns

### View issue from current branch
```bash
linear issue view
```

### List unstarted issues for specific team
```bash
linear issue list --team DEV --state unstarted
```

### List all your issues across states
```bash
linear issue list --all-states
```

### View issue with comments
```bash
linear issue view DEV-123
```

### List team members
```bash
linear team members DEV
```

### List active projects for a team
```bash
linear project list --team DEV
```

## Important Notes

- When `issueId` is optional and not provided, the command will try to extract it from the current git branch
- Use `--no-pager` if you need to process the output programmatically
- All view commands default to showing output in the terminal (not opening browser/app)
- The Linear CLI respects the `.linear.toml` configuration file for default teams and other settings
