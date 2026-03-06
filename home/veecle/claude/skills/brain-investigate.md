# Brain Investigate Skill

Research a topic by searching the second brain and external sources (GitHub, Linear), then synthesize findings into a structured report.

## Usage

The user will say something like "investigate X" or "research X" or "what do we know about X". The topic may be a technical concept, a project, a system component, or a cross-cutting concern.

## Workflow

### 1. Search the Brain

Search existing brain files for related notes:

```bash
rg -l "<topic>" ~/.local/share/second-brain/ --type md
```

Also search for related terms and variations. Read any matching files to gather existing context.

### 2. Search GitHub

Fan out across multiple GitHub search types:

```bash
# Issues and PRs mentioning the topic within the veecle org
gh search issues "<topic>" --owner=veecle --json title,repository,url,body,state --limit 10
gh search prs "<topic>" --owner=veecle --json title,repository,url,body,state --limit 10

# Code containing the topic (if it's a technical term)
gh search code "<topic>" --owner=veecle --json path,repository,url --limit 10
```

### 3. Search Linear

If the `linear` CLI is available:

```bash
# Search issue titles for the topic
linear issue list --all-states --all-assignees --no-pager 2>/dev/null | rg -i "<topic>" || true
```

For matching issues, get details:

```bash
linear issue view <issue-id> --no-pager
```

### 4. Synthesize Report

Create a report at `~/.local/share/second-brain/reports/<topic-slug>.md`:

```markdown
---
date: YYYY-MM-DD
topic: "<topic>"
---

## Investigation: <Topic>

## Summary
2-3 sentence overview of findings.

## Existing Brain Context
What the brain already knows about this topic (from journal entries, decisions, project overviews).

## GitHub Findings
Relevant issues, PRs, and code locations organized by repository.

## Linear Findings
Relevant issues and their current status.

## Connections
How this topic relates to known projects, people, and decisions.
Cross-reference with [[wiki-links]] where applicable.

## Open Questions
Things that remain unclear or need further investigation.
```

### 5. Update Daily Journal

Add an entry to today's daily note linking to the report:

```markdown
### HH:MM

Investigated [[reports/<topic-slug>|<topic>]]. Key findings: <one-line summary>.

#investigation
```

### 6. Commit

```bash
jj -R ~/.local/share/second-brain commit -m "investigate: <topic>"
```

## Guidelines

- Cast a wide net first, then filter for relevance
- Prioritize the user's own repos and issues over public noise
- When brain files already contain relevant context, lead with that — external sources supplement
- Include direct links (URLs) to GitHub issues/PRs for easy follow-up
- If Linear is unavailable, skip silently and note it in the report
- Keep the report concise — aim for actionable context, not exhaustive logs
