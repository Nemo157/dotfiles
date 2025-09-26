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

**When asked to modify global Claude configuration (the main CLAUDE.md, agents, etc.) from outside the dotfiles repository**: Remind the user to navigate to their dotfiles repository where the local AGENTS.md provides the proper configuration management workflow. Do not attempt to process global configuration changes from other contexts.

**Local/project-specific Claude configuration changes within other repositories should be handled directly in their respective contexts.**

