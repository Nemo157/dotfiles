# Dotfiles Repository Agent Guidelines

## Repository Overview

This is a comprehensive Nix-based dotfiles repository managing system and user configurations:

**System Level:** NixOS configurations (`nixos/`), custom packages (`packages/`), overlays (`overlays/`), and main flake configuration (`flake.nix`)

**Home Manager:** CLI tools (`home/cli/`), desktop environment (`home/desktop/`), development tools (`home/dev/`), work configs (`home/veecle/`), personal configs (`home/personal/`), and server configurations

**Repository Management:** Managed as a Nix flake with comprehensive system and user configurations

## Claude Configuration Management

This repository contains Claude configuration files at multiple levels:
- **Global configuration:** `home/dev/claude/` (main CLAUDE.md, agents, imports)
- **Profile-specific additions:** Additional context and permissions for specific environments
  - Example: `home/veecle/claude/` adds Veecle development practices and Linear MCP permissions via `lib.mkAfter`

When making configuration changes, follow the workflow and standards below.

### Configuration Workflow

**For Claude configuration changes within this repository:**
1. **Read existing patterns**: Use Read tool to examine current configurations
2. **Apply standards directly**: Follow the configuration standards documented below
3. **Make changes**: Use Edit, MultiEdit, Write as needed
4. **Validate changes**: Ensure YAML frontmatter and file structure are correct
5. **Update Nix integration**: Add new agents to `default.nix` when creating subagents

### File Locations and Path Mapping

When working in this repository, the actual files are at:
- `home/dev/claude/CLAUDE.md` - Main configuration
- `home/dev/claude/agents/` - Subagent definitions
- `home/dev/claude/imports/jj.md` - Jujutsu mappings
- `home/dev/claude/default.nix` - Nix configuration

These get symlinked to `~/.config/claude/` by the Nix configuration.

**Automatic Path Mapping:**
When you encounter paths containing `~/.config/claude/`, automatically map them to the corresponding dotfiles repository location:
- `~/.config/claude/*` → `<dotfiles-repo>/home/dev/claude/*`

### Configuration Standards to Apply

**YAML Frontmatter:**
- Use folded strings (`>`) for long single-paragraph descriptions
- Use literal blocks (`|`) when preserving line breaks and formatting is important
- Break long descriptions across multiple lines for readability
- Maintain proper indentation and syntax validation
- Include required fields (name, description, tools)

**File Organization:**
- Follow existing patterns in the repository
- Use consistent naming (kebab-case for agents)
- Ensure clean line endings, no trailing whitespace

**Nix Integration:**
- New agents require entry in `default.nix`
- Use format: `AGENT-NAME.source = ./agents/AGENT-NAME.md;`
- Without this entry, subagents won't be available

**Subagent Configuration Patterns:**
- Preserve functional XML tags (`<example>`, `<commentary>`) with proper formatting
- Structure examples with clear context, user input, assistant response, and commentary
- Ensure descriptions clearly explain when to use the subagent
- Include relevant examples that demonstrate the subagent's purpose

**Validation Approach:**
- Verify YAML frontmatter syntax is valid
- Check that required fields (name, description) are present
- Ensure formatting follows established patterns
- Validate that changes align with existing configuration structure

### Prohibited Actions

- Never modify symlinked targets in `~/.config/claude/`
- Don't bypass established patterns and validation approaches
- Don't create agents without proper Nix integration

This approach maintains configuration quality standards when working directly in the dotfiles repository.
