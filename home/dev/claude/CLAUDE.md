# Core Overrides

**File operations:**
- ALWAYS edit existing files over creating new ones
- NEVER create documentation files unless explicitly requested
- Files end with single newline, no trailing whitespace
- **Respect user modifications**: If file content differs from what you previously wrote/edited, assume the user changed it intentionally and preserve their intent - do not revert user modifications unless explicitly asked

**Version Control - MANDATORY:**
- **ALWAYS use `jj` instead of `git`** unless operating in a git worktree
- NEVER use git commands directly - always translate to jj equivalents
- This is a CORE REQUIREMENT, not a preference
- When running `jj commit`/`jj describe`, ALWAYS use single quotes for the `-m` argument
  (double quotes allow zsh to interpret backticks and other special characters)
- After every `jj commit`, trigger second-brain filing for the work context
- **Git worktrees:** When the system context says "You are operating in a git worktree", use `git` instead of `jj` — jj does not support git worktrees

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

**Exploring dependency source code:**
- Use `cargo metadata` to find the source path of a dependency:
  ```bash
  cargo metadata --format-version=1 | jq -r '.packages[] | select(.name == "CRATE_NAME") | .manifest_path'
  ```
- The manifest path points to the crate's `Cargo.toml`; the source files are in the same directory
- For git dependencies, source is under `$CARGO_HOME/git/checkouts/`
- For registry dependencies, source is under `$CARGO_HOME/registry/src/`
- Read the dependency source directly to understand APIs, types, and behavior

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
- In `rg`, `-r` means `--replace`, not `--recursive` like in `grep` (rg recurses by default) -
  don't reach for `-r` out of `grep` muscle memory. Bundling it into short-flag groups (e.g.
  `-rln`) is parsed as `--replace ln`, silently rewriting every match to `ln` instead of behaving
  like `-l -n`. Only use `-r` when a replacement is actually intended.
- Use `fd` instead of `find`
- For non-standard tools not installed locally, use `nix run pkgs#<package>` (e.g., `nix run pkgs#hexyl`)

**Note:** Version control tool preference is covered in Core Overrides as a mandatory requirement.

# Claude configuration changes

**When asked to modify global Claude configuration (the main CLAUDE.md, agents, etc.) from outside the dotfiles repository**: Remind the user to navigate to their dotfiles repository where the local AGENTS.md provides the proper configuration management workflow. Do not attempt to process global configuration changes from other contexts.

**Local/project-specific Claude configuration changes within other repositories should be handled directly in their respective contexts.**

