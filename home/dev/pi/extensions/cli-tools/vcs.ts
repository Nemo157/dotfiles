// Version-control tool selection.
//
// The jj and git wrappers overlap heavily: in a colocated repo `jj` can
// answer everything the git wrappers do, and exposing both just gives the
// model two ways to ask the same question (and a chance to reach for the
// git ones, which don't see the jj working copy). So we register exactly
// one of the two sets, chosen from the working directory at load time:
//
//   - inside a jj workspace (colocated or not) -> jj tools only
//   - inside a plain git repo                  -> git tools only
//   - neither                                  -> no VCS tools
//
// Detection runs in `process.cwd()`, which is the session's working
// directory at extension load — the same assumption the cargo/nix gates
// make.

import { commandOk, type CliToolDef } from "./shared";
import { jjTools } from "./jj";
import { gitTools } from "./git";

/** True when `process.cwd()` is inside a jj workspace. */
export function inJjRepo(): boolean {
  // --ignore-working-copy keeps this probe side-effect free (no snapshot).
  return commandOk("jj", ["root", "--ignore-working-copy"]);
}

/** True when `process.cwd()` is inside a git working tree. */
export function inGitRepo(): boolean {
  return commandOk("git", ["rev-parse", "--git-dir"]);
}

/**
 * Return the VCS tools appropriate for the current working directory.
 * jj wins over git because it covers colocated repos completely.
 */
export function getVcsTools(): CliToolDef[] {
  if (inJjRepo()) return [...jjTools];
  if (inGitRepo()) return [...gitTools];
  return [];
}
