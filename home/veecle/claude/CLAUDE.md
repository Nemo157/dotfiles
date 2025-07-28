# Bash commands

- Prefer using `rg` and `fd` instead of `grep` and `find`.
- Read `@jj.md` to see how to use `jj` as a replacement for `git`.
- Use `cargo clippy` instead of `cargo check`.

# Workflow

- Format output for issue descriptions as markdown but with syntax highlighting applied appropriately.
- Be very succinct in explaining what steps you will take.

## Rust projects

- When checking the code works:
  - First check the code builds with `cargo clippy --all-targets -- -Awarnings`
  - Then run tests
  - Then fix warnings from `cargo clippy --all-targets`
- NEVER use `unsafe` in Rust code.
- Only check the packages that have been modified, not the whole workspace.
