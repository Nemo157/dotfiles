// Warn before leaving a session while the repo has uncommitted changes.
//
// - `/new`, `/resume`, `/fork`, `/clone`: cancellable. A confirm dialog is
//   shown via `session_before_switch` / `session_before_fork`.
// - Quit (`/quit`, double ctrl+c, signals): pi has no cancellable quit
//   hook (`/quit` is matched before extension commands, `app.clear` is a
//   reserved shortcut), so on `session_shutdown` with reason "quit" we only
//   print a warning to stderr after the TUI has stopped, where it stays
//   visible in the terminal.
//
// "Uncommitted" means a non-empty `@` in a jj workspace (work is sealed with
// `jj commit`), checked against a fresh but unintegrated snapshot, otherwise a non-empty `git status --porcelain`. Outside a
// repo, or when a probe fails, nothing is reported. Without a UI (print/RPC
// mode) switches are never blocked.

import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const MAX_LISTED = 10;

interface Dirty {
  vcs: "jj" | "git";
  // One line per changed path, e.g. "M foo/bar.ts".
  files: string[];
}

function lines(stdout: string): string[] {
  return stdout.split("\n").filter((l) => l.trim().length > 0);
}

async function checkDirty(
  pi: ExtensionAPI,
  cwd: string,
): Promise<Dirty | undefined> {
  // `jj diff` snapshots the working copy, so the answer is current, but
  // `--no-integrate-operation` keeps that snapshot out of the op log (and
  // leaves the working-copy state alone), so the probe has no side effects.
  // The "operation left uncommitted" note goes to stderr. It fails outside a
  // jj workspace, in which case we fall back to git.
  const jj = await pi.exec(
    "jj",
    ["diff", "--summary", "--color=never", "--no-integrate-operation"],
    { cwd, timeout: 10_000 },
  );
  if (jj.code === 0) {
    const files = lines(jj.stdout);
    return files.length > 0 ? { vcs: "jj", files } : undefined;
  }

  const git = await pi.exec("git", ["status", "--porcelain"], {
    cwd,
    timeout: 10_000,
  });
  if (git.code === 0) {
    const files = lines(git.stdout).map((l) => l.trim());
    return files.length > 0 ? { vcs: "git", files } : undefined;
  }

  return undefined;
}

function describe(dirty: Dirty): string {
  const where = dirty.vcs === "jj" ? "in @" : "in the working tree";
  const n = dirty.files.length;
  return `${n} uncommitted file${n === 1 ? "" : "s"} ${where}`;
}

function listing(dirty: Dirty): string {
  const shown = dirty.files.slice(0, MAX_LISTED).map((f) => `  ${f}`);
  const rest = dirty.files.length - shown.length;
  if (rest > 0) shown.push(`  … and ${rest} more`);
  return shown.join("\n");
}

async function guard(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  action: string,
): Promise<{ cancel: boolean } | undefined> {
  if (!ctx.hasUI) return;

  const dirty = await checkDirty(pi, ctx.cwd);
  if (!dirty) return;

  const proceed = `Yes, ${action} anyway`;
  const choice = await ctx.ui.select(
    `${describe(dirty)}:\n${listing(dirty)}\n\n${action} anyway?`,
    [proceed, "No, cancel"],
  );
  if (choice === proceed) return;

  ctx.ui.notify(`Cancelled ${action}: ${describe(dirty)}`, "warning");
  return { cancel: true };
}

export default function dirtyGuardExtension(pi: ExtensionAPI): void {
  pi.on("session_before_switch", async (event, ctx) =>
    guard(pi, ctx, event.reason === "new" ? "start a new session" : "resume"),
  );

  pi.on("session_before_fork", async (event, ctx) =>
    guard(pi, ctx, event.position === "at" ? "clone" : "fork"),
  );

  pi.on("session_shutdown", async (event, ctx) => {
    if (event.reason !== "quit" || !ctx.hasUI) return;

    const dirty = await checkDirty(pi, ctx.cwd);
    if (!dirty) return;

    // The TUI is already stopped here, so plain stderr lands below the
    // final frame. Yellow, matching the usual warning colour.
    process.stderr.write(
      `\x1b[33mWarning: ${describe(dirty)} (${ctx.cwd}):\x1b[0m\n` +
        `${listing(dirty)}\n`,
    );
  });
}
