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

## Code Review
- **Use code-reviewer subagent** for reviewing recently written code, ensuring best practices, and catching potential issues before committing
- Code reviews focus on quality, architecture, and correctness - build verification is handled separately

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

**CRITICAL REQUIREMENT: ALL Claude configuration changes MUST use the `config-manager` subagent IMMEDIATELY - never attempt manual file operations first.**

## When to Use Config-Manager

**ALWAYS use config-manager when you encounter these patterns:**
- "update your prompt" / "modify your prompt" (refers to CLAUDE.md)
- "modify [subagent] behavior" / "change how [agent] works"
- "configure Claude to..." / "set up Claude to..."
- "update CLAUDE.md" / "change your instructions"
- "create/modify/delete subagent"
- "add new behavior" / "change existing behavior"
- Any mention of CLAUDE.md, subagent files, or Claude settings

## Prohibited Actions

**NEVER perform these actions manually for configuration tasks:**
- Direct file editing of CLAUDE.md or subagent files
- Creating new subagent files without config-manager
- Modifying YAML frontmatter manually
- Making configuration changes as a "quick fix"

## Required Process

1. **Recognize** configuration task from user request
2. **Use config-manager IMMEDIATELY** - no manual attempts first
3. **Let config-manager handle** all formatting, validation, and structure
4. **Trust the specialist** - config-manager ensures consistency and best practices

The config-manager subagent ensures proper formatting, consistency, adherence to established patterns, and maintains the integrity of the Claude configuration system.
