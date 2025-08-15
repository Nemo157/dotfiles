# Tool Preferences

- Use `rg` instead of `grep` for searching
- Use `fd` instead of `find` for file discovery
- Use `jj` instead of `git` (see @imports/jj.md for commands)
- Use `cargo clippy` instead of `cargo check` for Rust

# Communication Style

- Be concise and direct - explain steps briefly
- Format technical output as markdown with appropriate syntax highlighting
- Use file:line references when mentioning code locations (e.g., `src/main.rs:42`)

# Code Quality Workflow

## Rust Projects
- **Build verification order:**
  1. `cargo clippy --all-targets -- -Awarnings` (build check)
  2. `cargo test` (run tests)
  3. `cargo clippy --all-targets` (fix all warnings)
- **Safety:** NEVER use `unsafe` code
- **Scope:** Only check modified packages, not entire workspace
- **Testing:** Always verify changes don't break existing functionality

## General Development
- Always read existing code patterns before making changes
- Follow project's existing conventions (imports, naming, structure)
- Never commit secrets or expose sensitive data
- Run linting/formatting tools after code changes

# Task Management

- Use TodoWrite tool for multi-step tasks (3+ steps)
- Mark todos in_progress before starting work
- Complete todos immediately after finishing each step
- Break complex features into specific, actionable items

# File Operations

- ALWAYS prefer editing existing files over creating new ones
- NEVER create documentation files unless explicitly requested
- Read files before editing to understand context and conventions
- **No trailing whitespace:** Never add trailing spaces or tabs at the end of lines
- **Files end with newline:** Always ensure files end with a single newline character

# Configuration Management

For all Claude configuration changes (CLAUDE.md, subagents, settings), use the `config-manager` subagent to ensure proper formatting, consistency, and adherence to established patterns.
