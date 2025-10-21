# Jujutsu (jj) System Prompt

When working with version control, use Jujutsu (jj) instead of Git. Here are the key concepts and command mappings:

## Core Concepts
- **Working copy revision (`@`)**: Current working directory state, analogous to Git's working tree + staging area
- **Bookmarks**: Like Git branches, but lighter weight (use `jj bookmark` or `jj b`)
- **Revisions**: Immutable snapshots, identified by change IDs or revision IDs
- **Operations**: All jj commands are operations that can be undone with `jj op undo`
- **Automatic snapshotting**: Working copy is automatically committed before each command

## Essential Command Mappings

### Status and History
- `jj status` ≈ `git status` + `git log --oneline -1`
- `jj log` ≈ `git log --graph --oneline` (shows concise graphical history by default)
- `jj log --limit <n>` ≈ `git log --oneline -n` (limit number of commits shown)
- `jj log --revisions ::` ≈ `git log --all --graph` (show all revisions)
- `jj show --git --color=never <rev>` ≈ `git show <rev>` (show specific revision with full commit message and patch)
  - Use `jj show --git --color=never @-` to inspect the most recent commit with complete details
  - Use `jj show --git --color=never <rev>-` to inspect the parent of a specific revision
  - Prefer `jj show` over `jj log --patch` for examining individual commits
  - Use `--git --color=never` for standard unified diffs without color codes (simpler and matches AI training data)
- `jj log --patch` ≈ `git log -p` (show patches for range of revisions)

### Working with Changes
- `jj new` ≈ `git checkout -b` (create new revision and switch to it)
- `jj commit --message "description"` ≈ `git commit -a` (snapshot current changes and create new working copy)
  - **Prefer `jj commit` over `jj describe`** when you want to move to a clean working directory
  - `jj commit` creates a new empty working copy revision, leaving previous work finalized
  - `jj describe` only updates the commit message without creating a new working copy
- `jj edit <revision>` ≈ `git checkout <commit>` (switch working copy to revision)
- `jj diff --git --color=never` ≈ `git diff HEAD` (show working copy changes)
- `jj diff --git --color=never --revisions <rev>` ≈ `git show <rev>` (show changes in revision)
- `jj diff --git --color=never --from main` ≈ `git diff main..HEAD` (show all changes since main)
- `jj diff --git --color=never --revisions main..@` ≈ `git diff main..HEAD` (alternative syntax for range)

### Branching and Bookmarks
- `jj bookmark create <name>` ≈ `git branch <name>`
- `jj bookmark set <name>` ≈ `git checkout -B <name>`
- `jj bookmark list` ≈ `git branch -v`
- `jj bookmark delete <name>` ≈ `git branch -d <name>`

**Bookmark Management:**
- **NEVER proactively create bookmarks** - jj automatically names them
- Only create bookmarks when explicitly requested by the user
- jj handles bookmark naming automatically during normal workflow

### Rebasing and History Editing
- `jj rebase --source <source> --destination <dest>` ≈ `git rebase <dest> <source>` (move source and descendants)
- `jj rebase --revisions <rev> --destination <dest>` ≈ interactive rebase single commit
- `jj squash` ≈ `git commit --amend` or `git rebase -i` (move changes to parent)
  - **Always supply a message** with `--message` unless the source commit has `(no description set)` to avoid interactive editor
  - Example: `jj squash --from @- --into @-- --message "combined commit message"`
  - Without `--message`, jj will open an interactive editor to combine commit messages
- `jj split` ≈ `git reset --soft HEAD~1` + selective commits

### File Operations
- `jj file show --revision <rev> <file>` ≈ `git show <rev>:<file>`
- `jj file list` ≈ `git ls-files`
- `jj restore <file>` ≈ `git checkout HEAD -- <file>`

**Working Copy File Manipulation:**
- Use standard shell commands (`mv`, `cp`, `rm`) to manipulate files in the working copy
- `mv` ≈ `git mv` - jj automatically detects file moves, renames, and deletions through auto-snapshotting
- **Do NOT** try to use jj commands for basic file operations
- Examples:
  - Move files: `mv old/path.txt new/path.txt` (jj will detect as rename)
  - Copy files: `cp source.txt dest.txt`
  - Delete files: `rm file.txt`
- After file operations, `jj status` will show the changes (including properly tracked renames)

### Remote Operations (Git interop)
- `jj git fetch` ≈ `git fetch`
- `jj git push` ≈ `git push`
- `jj git clone <url>` ≈ `git clone <url>`
- `jj git import` ≈ synchronize from underlying Git repo
- `jj git export` ≈ synchronize to underlying Git repo

### Conflict Resolution
- Conflicts are represented as special conflict files
- **NEVER use `jj resolve`** - edit conflicts manually in files
- For complex conflicts:
  1. `jj new` to create new revision on conflicted revision
  2. Fix conflicts manually
  3. Test the fixes
  4. `jj squash` to merge resolution into original revision

### Advanced Operations
- `jj describe <rev> --message "commit message"` ≈ `git commit --amend -m` (update commit message for specific revision)
  - Use `jj describe @- --message "commit message"` to update the most recent commit's message
  - Use `jj describe @ --message "commit message"` to update the working copy revision's message
- `jj abandon <rev>` ≈ `git reset --hard HEAD~1` (remove revision)
- `jj duplicate <rev>` ≈ `git cherry-pick <rev>`
- `jj parallelize <revs>` ≈ make revisions siblings instead of linear

### Commit Message Updates After Squashing
When updating commit messages after a `jj squash` operation, follow this workflow:

1. **Check where changes landed**: After squashing, changes typically move to an earlier commit (often `@-`), leaving the current commit (`@`) empty
2. **Verify with log**: Use `jj log` to see the current state and identify which commit contains your actual changes
3. **Inspect commits**: Use `jj show @` and `jj show @-` to verify which commit contains the changes before updating the message
4. **Update the correct commit**: Apply `jj describe --revision <correct-rev>` to the commit that actually contains your changes, not necessarily the current working copy

**Example workflow:**
```bash
# After making changes and squashing
jj squash
jj log                           # Check where changes ended up
jj show --git --color=never @    # Check if current commit has changes (often empty)
jj show --git --color=never @-   # Check if parent commit has your changes
jj describe @- --message "your commit message"  # Update the commit with actual changes
```

### Operation Log (Undo/Redo)
- `jj op log` ≈ `git reflog` (show operation history)
- `jj op undo` or `jj undo` ≈ undo last operation
- `jj op restore --at-op <op>` ≈ reset to specific operation

### Navigation
- `jj prev` ≈ move to parent revision
- `jj next` ≈ move to child revision

## Important Behavioral Differences

1. **Auto-snapshotting**: jj automatically saves working copy state before operations
2. **No staging area**: Changes are immediately visible in working copy revision
3. **Immutable revisions**: Once created, revisions cannot be modified (only abandoned/replaced)
4. **Conflicts as first-class**: Conflicted states are stored and can be committed
5. **Change IDs**: Revisions have stable change IDs that persist across rebases

## Revset Syntax Differences

Jujutsu uses different operators than Git for parent/ancestor references:
- **Parent of revision**: Use `<rev>-` (NOT `<rev>^` like Git)
  - `jj show --git --color=never @-` shows parent of working copy
  - `jj show --git --color=never <commit-id>-` shows parent of specific commit
- **Ancestors**: Use `<rev>-` for immediate parent, `<rev>--` for grandparent, etc.
- **Range queries**: Use `main..<rev>` for commits between main and rev
- **All ancestors**: Use `::<rev>` to show all ancestors of a revision

## Commit Message Style

Commit messages should focus on user-facing changes and the reason for them:

- Describe the user-facing change and the reason for it
- Avoid implementation details of how the change was achieved
- When rewriting commits, don't reference intermediate states or refactoring steps from development
- Avoid phrases like "extracted function X", "refactored Y", "eliminated nested matches", "simplified by removing..." unless the refactoring itself is the purpose
- Focus on what problem was fixed and why, not the specific code changes or intermediate states

**Examples:**

Good:
- `fix parsing of nested expressions in error messages`
- `add timeout handling to prevent hangs on slow networks`

Avoid:
- `eliminate nested matches and refactor error handling` (focuses on implementation)
- `simplified by extracting helper function` (focuses on refactoring steps)

## Workflow Patterns

### Basic workflow:
```bash
jj status                    # Check current state
jj new                       # Create new change
# Make edits
jj commit --message "description"   # Finalize change
jj git push                  # Push to remote
```

### Working with branches:
```bash
jj bookmark create feature
jj new                       # Start working
# Make changes
jj commit --message "implement feature"
jj rebase --source @ --destination main      # Rebase onto main
jj git push --bookmark feature      # Push bookmark
```

### Fixing conflicts:
```bash
# After a rebase creates conflicts:
jj new                      # Create new revision on conflicted state
# Edit files to resolve conflicts
jj status                   # Verify resolution
jj squash                   # Merge resolution back
```

Use these mappings and patterns when working with jj instead of git commands.
