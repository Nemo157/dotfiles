# Core Overrides

**File operations:**
- ALWAYS edit existing files over creating new ones
- NEVER create documentation files unless explicitly requested
- Files end with single newline, no trailing whitespace
- **Respect user modifications**: If file content differs from what you previously wrote/edited, assume the user changed it intentionally and preserve their intent - do not revert user modifications unless explicitly asked

**Version Control - MANDATORY:**
- **ALWAYS use `jj` instead of `git` - NO EXCEPTIONS**
- NEVER use git commands directly - always translate to jj equivalents
- Reference @imports/jj.md for command mappings and workflow patterns
- If unsure about a jj command, consult the mapping guide
- This is a CORE REQUIREMENT, not a preference

**Task tracking:**
- Use TodoWrite for multi-step tasks (3+ steps)
- Mark in_progress before starting, complete immediately after finishing

# Personal Information

**GitHub Identity:**
- GitHub username: `Nemo157`
- When you see comments or code authored by "Nemo157" on GitHub, this refers to the user

# Communication & Style

- Be concise and direct
- Use file:line references (e.g., `src/main.rs:42`)
- Format code output with appropriate syntax highlighting
- Avoid empty qualifiers like "comprehensive", "detailed", "extensive"
- Use concrete descriptors that provide actual information about scope and content

# Development Practices

**Code patterns:**
- Read existing code before making changes
- Follow project conventions (imports, naming, structure)
- Never commit secrets or expose sensitive data

**Naming conventions:**
- Remove redundant prefixes when context is clear (`TelemetryMessage` → `Telemetry`)
- Use simple variable names (`telemetry_msg` → `message`)
- Choose clarity over verbosity

**Rust workflow:**
1. `cargo clippy --all-targets -- -Awarnings` (build check)
2. `cargo test` (run tests)
3. `cargo clippy --all-targets` (fix warnings)
- NEVER use `unsafe` code
- Only check modified packages, not entire workspace
- Use code-reviewer subagent after significant changes

# Tool Preferences

- Use `rg` instead of `grep`
- Use `fd` instead of `find`
- For non-standard tools not installed locally, use `nix run pkgs#<package>` (e.g., `nix run pkgs#hexyl`)

**Note:** Version control tool preference is covered in Core Overrides as a mandatory requirement.

# Claude configuration changes

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
