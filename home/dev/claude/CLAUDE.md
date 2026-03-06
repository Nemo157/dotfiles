# Core Overrides

**File operations:**
- ALWAYS edit existing files over creating new ones
- NEVER create documentation files unless explicitly requested
- Files end with single newline, no trailing whitespace
- **Respect user modifications**: If file content differs from what you previously wrote/edited, assume the user changed it intentionally and preserve their intent - do not revert user modifications unless explicitly asked

**Version Control - MANDATORY:**
- **ALWAYS use `jj` instead of `git` - NO EXCEPTIONS**
- NEVER use git commands directly - always translate to jj equivalents
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

**Commit messages:**
- Use markdown formatting for clarity
- Wrap inline code, commands, file names, function names, etc. in backticks
- Examples: "fix `parse_config` to handle empty strings", "update `Cargo.toml` dependencies"

**Naming conventions:**
- Remove redundant prefixes when context is clear (`TelemetryMessage` → `Telemetry`)
- Use simple variable names (`telemetry_msg` → `message`)
- Choose clarity over verbosity

**Rust workflow:**
1. `cargo clippy --all-targets -- -Awarnings` (build check)
2. `cargo test` (run tests)
3. `cargo clippy --all-targets` (fix warnings)
- NEVER use `unsafe` code
- NEVER run `cargo clean` - it's rarely necessary and wastes time rebuilding
- Only check modified packages, not entire workspace

**Rust coding patterns:**
- Prefer `T::from_str()` over `.parse()` variants - more explicit about type construction and import dependencies
  ```rust
  // Prefer: let num = i32::from_str("42")?;
  // Over:   let num = "42".parse::<i32>()?;
  // Over:   let num: i32 = "42".parse()?;
  ```
- Prefer `T::from_iter()` over `.collect()` variants - clearer target type at construction site
  ```rust
  // Prefer: let vec = Vec::from_iter(iterator);
  // Over:   let vec = iterator.collect::<Vec<_>>();
  // Over:   let vec: Vec<_> = iterator.collect();
  ```

# Tool Preferences

- Use `rg` instead of `grep`
- Use `fd` instead of `find`
- For non-standard tools not installed locally, use `nix run pkgs#<package>` (e.g., `nix run pkgs#hexyl`)

**Note:** Version control tool preference is covered in Core Overrides as a mandatory requirement.

# Problem Tracking

When you encounter a problem during a session, log it for later review using `log-problem`. This captures issues that could be prevented by config or rules improvements.

**When to log:**
- You get corrected by the user (wrong tool, wrong approach, wrong assumption)
- You have to retry or redo something due to a mistake
- A permission issue slows you down (had to ask when it should have been auto-allowed)
- You make a wrong assumption about tooling, project structure, or conventions
- Something the rules should have covered but didn't

**Timing:** Log problems IMMEDIATELY when they occur (right after the retry or workaround), not at the end of a task. Deferring leads to forgetting. If inside a subagent, include problems in the response for the parent to log on return.

**How to log:**
```bash
log-problem <project-name> "<what went wrong and what was attempted>"
```

Use the project directory name (e.g. `dotfiles`, `my-app`). The description should briefly cover what went wrong and what you tried or how you recovered.

**Do not log:**
- Normal exploratory steps (searching, reading code)
- User-requested changes in direction
- External failures (network issues, flaky tests)

**Subagents:**
- When spawning subagents via the Task tool, instruct them to report any problems they encounter in their response
- Log problems on behalf of subagents based on what they report back

# Claude configuration changes

**When asked to modify global Claude configuration (the main CLAUDE.md, agents, etc.) from outside the dotfiles repository**: Remind the user to navigate to their dotfiles repository where the local AGENTS.md provides the proper configuration management workflow. Do not attempt to process global configuration changes from other contexts.

**Local/project-specific Claude configuration changes within other repositories should be handled directly in their respective contexts.**

