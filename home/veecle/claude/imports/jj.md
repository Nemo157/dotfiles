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
- `jj status` (or `jj st`) ≈ `git status` + `git log --oneline -1`
- `jj log` ≈ `git log --graph --oneline` (shows concise graphical history by default)
- `jj log --limit <n>` ≈ `git log --oneline -n` (limit number of commits shown)
- `jj log -r ::` ≈ `git log --all --graph` (show all revisions)
- `jj show <rev>` ≈ `git show <rev>` (show specific revision with full commit message and patch)
  - Use `jj show @-` to inspect the most recent commit with complete details
  - Use `jj show <rev>-` to inspect the parent of a specific revision
  - Prefer `jj show` over `jj log -p` for examining individual commits
- `jj log -p` ≈ `git log -p` (show patches for range of revisions)

### Working with Changes
- `jj new` ≈ `git checkout -b` (create new revision and switch to it)
- `jj commit` (or `jj ci`) ≈ `git commit -a` (snapshot current changes and create new working copy)
- `jj edit <revision>` ≈ `git checkout <commit>` (switch working copy to revision)
- `jj diff` ≈ `git diff HEAD` (show working copy changes)
- `jj diff -r <rev>` ≈ `git show <rev>` (show changes in revision)
- `jj diff -r main..@` ≈ `git diff main..HEAD` (show all changes in current branch since main)

### Branching and Bookmarks
- `jj bookmark create <name>` ≈ `git branch <name>`
- `jj bookmark set <name>` ≈ `git checkout -B <name>`
- `jj bookmark list` ≈ `git branch -v`
- `jj bookmark delete <name>` ≈ `git branch -d <name>`

### Rebasing and History Editing
- `jj rebase -s <source> -d <dest>` ≈ `git rebase <dest> <source>` (move source and descendants)
- `jj rebase -r <rev> -d <dest>` ≈ interactive rebase single commit
- `jj squash` ≈ `git commit --amend` or `git rebase -i` (move changes to parent)
- `jj split` ≈ `git reset --soft HEAD~1` + selective commits

### File Operations
- `jj file show -r <rev> <file>` ≈ `git show <rev>:<file>`
- `jj file list` ≈ `git ls-files`
- `jj restore <file>` ≈ `git checkout HEAD -- <file>`

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
- `jj describe -r <rev>` (or `jj desc -r <rev>`) ≈ `git commit --amend -m` (update commit message for specific revision)
  - Use `jj describe -r @-` to update the most recent commit's message
  - Use `jj describe -r @` to update the working copy revision's message
- `jj abandon <rev>` ≈ `git reset --hard HEAD~1` (remove revision)
- `jj duplicate <rev>` ≈ `git cherry-pick <rev>`
- `jj parallelize <revs>` ≈ make revisions siblings instead of linear

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
  - `jj show @-` shows parent of working copy
  - `jj show <commit-id>-` shows parent of specific commit
- **Ancestors**: Use `<rev>-` for immediate parent, `<rev>--` for grandparent, etc.
- **Range queries**: Use `main..<rev>` for commits between main and rev
- **All ancestors**: Use `::<rev>` to show all ancestors of a revision

## Workflow Patterns

### Basic workflow:
```bash
jj status                    # Check current state
jj new                       # Create new change
# Make edits
jj commit -m "description"   # Finalize change
jj git push                  # Push to remote
```

### Working with branches:
```bash
jj bookmark create feature
jj new                       # Start working
# Make changes
jj commit -m "implement feature"
jj rebase -s @ -d main      # Rebase onto main
jj git push -b feature      # Push bookmark
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
