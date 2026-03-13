# Veecle Development Practices

Read @~/sources/veecle/style-guide/.agents/rules/shared/AGENTS.md for Veecle specific development practices.

## Commit Workflow

Before committing in Veecle repositories, ask whether there's a related Linear
issue to reference in the commit message. Include the reference as a trailer:
either `Refs: DEV-1234` or `Closes: DEV-1234` depending on whether the commit
fully resolves the issue. Skip the prompt for trivial changes like typo fixes or
formatting.
