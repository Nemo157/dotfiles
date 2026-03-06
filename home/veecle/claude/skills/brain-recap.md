# Brain Recap Skill

Summarize recent work from the second brain's journal entries for a specified time period.

## Usage

The user will say something like "recap my week", "what did I do last month", "summarize this week", or just "recap". Default to the current week if no period is specified.

## Workflow

### 1. Determine Period

Parse the user's request to determine the date range:

- "this week" / "my week" / "recap" → Monday through today
- "last week" → previous Monday through Sunday
- "this month" → 1st of current month through today
- "last month" → 1st through last day of previous month
- Specific dates → use as given

### 2. Read Journal Entries

Read all daily entries in the period:

```bash
ls ~/.local/share/second-brain/journal/daily/
```

Read each matching file. If a weekly or monthly rollup already exists for the period, read that too for comparison.

### 3. Generate Summary

Present a structured recap:

```markdown
## Recap: YYYY-MM-DD to YYYY-MM-DD

### Projects
For each project mentioned in journal entries:
- **Project Name**: Summary of work done, key progress, blockers

### Tasks
- **Completed**: Tasks marked done during this period
- **In Progress**: Tasks actively worked on
- **New**: Tasks created during this period
- **Blocked**: Tasks that hit blockers

### People
Notable interactions, collaborations, handoffs.

### Decisions
Any decision records filed during this period, with brief context.

### Key Findings
Investigation reports, debugging discoveries, architecture insights.

### Tags
Aggregate of tags used during the period, showing focus areas.

### Sources
- [[journal/daily/YYYY-MM-DD|YYYY-MM-DD]] (one entry per daily note included in this recap)
```

The Sources section creates backlinks to every daily entry that was summarized, connecting the recap to its source documents in the graph view.

### 4. Offer to File

After presenting the recap, ask:

> "Want me to save this as a weekly/monthly rollup?"

If confirmed, write to the appropriate rollup file (always include the Sources section):

- Weekly: `journal/weekly/YYYY-Www.md`
- Monthly: `journal/monthly/YYYY-MM.md`

And commit:

```bash
jj -R ~/.local/share/second-brain commit -m "recap: YYYY-Www" 
```

## Guidelines

- If there are no entries for the requested period, say so plainly
- When a rollup already exists, present it and note any daily entries that were added after it was generated
- Keep project summaries to 1-2 sentences each
- Highlight patterns: "You spent most of the week on X" or "Context-switched between 4 projects"
- Include quantitative signals where possible: "3 PRs merged, 2 issues closed"
