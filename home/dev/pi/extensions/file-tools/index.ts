// file-tools: local pi extension exposing basic filesystem mutations.
//
// The permission-system extension denies the raw `bash` tool, and the
// sibling `cli-tools` extension only wraps read-only commands. This
// extension fills the gap with the mutating file operations an agent
// routinely needs — move, delete, copy, and make-directory — implemented
// directly on top of `node:fs/promises` rather than shelling out.
//
// Why native fs instead of wrapping mv/rm/cp/mkdir?
//   - No PATH dependency and no GNU-vs-BSD flag skew (this repo targets both
//     NixOS and macOS).
//   - Structured errors (err.code === "ENOENT"/"EEXIST"/"EXDEV") instead of
//     scraping stderr.
//   - Precise control: mimic `mv`/`cp` "into an existing directory"
//     semantics and fall back to copy+unlink across filesystems (EXDEV),
//     which a naive fs.rename would get wrong.
//
// Permission model (see ../../default.nix):
//   - `rm`/`mkdir` expose their single target as `input.path`, which the
//     permission system extracts automatically. So the shared `path` deny
//     globs (*.age, **/.ssh/**, …) protect the target for free, and — since
//     these tool names are NOT in the `allow` list — each call falls through
//     to the `"*" = "ask"` default and is confirmed by the user.
//   - `mv`/`cp` instead name their two paths `source` and `dest`. The default
//     `input.path` extractor cannot see either, so we register a
//     `registerToolAccessExtractor` that points the shared `path` +
//     `external_directory` gates at `dest`: copying/moving into an external
//     directory raises a real approval prompt (even under edit-toggle=allow,
//     since `external_directory` is a bounded-delegation-excluded surface),
//     and the `path` deny globs cover the destination.
//   - The gate has only one path slot per tool, so re-aiming it at `dest`
//     leaves the SOURCE ungated. Each tool's run() compensates: it re-checks
//     the precise basename-joined destination against the `path` deny globs (a
//     synchronous extractor can't stat `dest` to know whether a basename is
//     appended), and guards the source itself — `path` deny globs, plus
//     blocking an EXTERNAL source outright. The source block is a deny, not a
//     prompt: we can't raise an interactive prompt from execute(), and without
//     it an auto-approved (edit-toggle=allow) call could read a file from
//     outside the working directory with no confirmation at all.
//   - The tools are also registered with the `edit-toggle` extension's
//     governed set, so flipping edits to "deny" disables them too.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type, type TSchema } from "typebox";
import * as fs from "node:fs/promises";
import { homedir } from "node:os";
import * as path from "node:path";

// ── permission service (dependency-free accessor) ──────────────────────────
// Mirror edit-toggle's approach: read the Symbol.for-backed service straight
// off globalThis so this extension needs no package.json / node_modules.
const SERVICE_KEY = Symbol.for("@gotgenes/pi-permission-system:service");

interface PermissionCheckResult {
  state: "allow" | "deny" | "ask";
}
type ToolAccessExtractor = (
  input: Record<string, unknown>,
) => string | undefined;
interface PermissionsService {
  checkPermission(surface: string, value?: string): PermissionCheckResult;
  registerToolAccessExtractor(
    toolName: string,
    extractor: ToolAccessExtractor,
  ): () => void;
}

function getPermissionsService(): PermissionsService | undefined {
  return (globalThis as Record<symbol, unknown>)[SERVICE_KEY] as
    | PermissionsService
    | undefined;
}

/**
 * Whether the permission policy denies `resolved` on the `path` surface — the
 * deny globs (*.age, **\/.ssh/**, …). Used to guard both the source (whose
 * gate coverage we trade away by re-aiming the access extractor at `dest`)
 * and the precise basename-joined destination. Fails open only when the
 * service is unavailable (mirrors the graceful degradation the
 * cross-extension API prescribes).
 */
function pathPolicyDenies(resolved: string): boolean {
  try {
    const svc = getPermissionsService();
    if (!svc) return false;
    return svc.checkPermission("path", resolved).state === "deny";
  } catch {
    // Never let a policy-check failure crash the tool.
    return false;
  }
}

/** Lexical (non-symlink-resolved) outside-cwd test, matching displayPath. */
function isOutsideWorkingDirectory(cwd: string, resolved: string): boolean {
  const rel = path.relative(cwd, resolved);
  return (
    rel !== "" &&
    (rel === ".." || rel.startsWith(`..${path.sep}`) || path.isAbsolute(rel))
  );
}

/**
 * Whether an EXTERNAL source path must be blocked outright.
 *
 * The built-in gates evaluate a single path per tool, and we point them at
 * `dest` (which therefore gets a real external-directory prompt). That leaves
 * the mv/cp SOURCE ungated: with edit-toggle=allow auto-approving the tool
 * call, `cp /elsewhere/secret .` would otherwise read an external file with no
 * prompt at all. We cannot raise an interactive prompt from inside execute(),
 * so treat anything the `external_directory` policy would not explicitly
 * `allow` (i.e. `ask` or `deny`) as blocked when the source is outside the
 * working directory. Paths inside the cwd, and external paths covered by an
 * `allow` rule (reference dirs), pass through. Fails open only when the
 * service is unavailable (the gates are off then too).
 */
function externalSourceBlocked(cwd: string, resolved: string): boolean {
  if (!isOutsideWorkingDirectory(cwd, resolved)) return false;
  try {
    const svc = getPermissionsService();
    if (!svc) return false;
    return (
      svc.checkPermission("external_directory", resolved).state !== "allow"
    );
  } catch {
    return false;
  }
}

// ── path helpers ────────────────────────────────────────────────────────
/** Expand a leading `~`; fs APIs don't do shell tilde expansion. */
function expandTilde(p: string): string {
  if (p === "~") return homedir();
  if (p.startsWith("~/")) return `${homedir()}/${p.slice(2)}`;
  return p;
}

/** Resolve a user-supplied path against the session cwd. */
function resolvePath(cwd: string, p: string): string {
  return path.resolve(cwd, expandTilde(p));
}

async function isDirectory(p: string): Promise<boolean> {
  try {
    return (await fs.stat(p)).isDirectory();
  } catch {
    return false;
  }
}

async function exists(p: string): Promise<boolean> {
  try {
    await fs.lstat(p);
    return true;
  } catch {
    return false;
  }
}

/** Present a path relative to cwd when it's inside it, else absolute. */
function displayPath(cwd: string, abs: string): string {
  const rel = path.relative(cwd, abs);
  return rel && !rel.startsWith("..") ? rel : abs;
}

// ── tool framework ────────────────────────────────────────────────────────
interface FileToolContext {
  cwd: string;
}

interface RunResult {
  /** One-line human summary, shown in the TUI result row. */
  line: string;
  isError?: boolean;
}

interface FileToolDetails {
  line: string;
}

interface FileToolDef<T extends TSchema> {
  name: string;
  label: string;
  description: string;
  parameters: T;
  /** Styled header fragment for renderCall (already themed). */
  header: (args: Record<string, unknown>, theme: RenderTheme) => string;
  run: (
    params: Record<string, unknown>,
    ctx: FileToolContext,
  ) => Promise<RunResult>;
}

// Minimal structural type for the bits of the theme we touch, so we don't
// depend on pi's private Theme export.
interface RenderTheme {
  fg(role: string, text: string): string;
  bold(text: string): string;
}

function registerFileTool<T extends TSchema>(
  pi: ExtensionAPI,
  def: FileToolDef<T>,
): void {
  pi.registerTool({
    name: def.name,
    label: def.label,
    description: def.description,
    parameters: def.parameters,
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      let result: RunResult;
      try {
        result = await def.run(
          params as Record<string, unknown>,
          { cwd: ctx.cwd },
        );
      } catch (err) {
        result = { line: `${def.name}: ${(err as Error).message}`, isError: true };
      }
      const details: FileToolDetails = { line: result.line };
      return {
        content: [{ type: "text", text: result.line }],
        details,
        isError: result.isError ?? false,
      };
    },
    renderCall(args, theme, _context) {
      const head =
        theme.fg("toolTitle", theme.bold(`${def.name} `)) +
        def.header(args as Record<string, unknown>, theme as RenderTheme);
      return new Text(head, 0, 0);
    },
    renderResult(result, opts, theme, _context) {
      if (opts.isPartial) return new Text("", 0, 0);
      const details = result.details as FileToolDetails | undefined;
      const first = result.content?.[0];
      const msg =
        details?.line ??
        (first && first.type === "text" ? first.text : "(done)");
      return new Text(theme.fg(result.isError ? "error" : "success", msg), 0, 0);
    },
  });
}

// ── parameter fragments ─────────────────────────────────────────────────
const pathParam = Type.String({
  description: "Filesystem path; relative to cwd, `~` expands to $HOME.",
});

// mv/cp name their source `source` rather than `path`: the built-in access
// extractor's `input.path` convention no longer applies to them (we register a
// custom `dest` extractor — see registerDestinationGating), so `path` would
// only mislead. rm/mkdir keep `path` because they still rely on that
// convention to auto-gate their single target.
const sourceParam = Type.String({
  description: "Source path; relative to cwd, `~` expands to $HOME.",
});

// ── mv ────────────────────────────────────────────────────────────────────
const mvParams = Type.Object({
  source: sourceParam,
  dest: Type.String({
    description:
      "Destination path. An existing directory means 'move inside it'.",
  }),
});

const mvTool: FileToolDef<typeof mvParams> = {
  name: "mv",
  label: "move",
  description:
    "Move or rename a file or directory. Works across filesystems.",
  parameters: mvParams,
  header(args, theme) {
    const src = typeof args.source === "string" ? args.source : "…";
    const dest = typeof args.dest === "string" ? args.dest : "…";
    return (
      theme.fg("accent", src) +
      theme.fg("muted", " → ") +
      theme.fg("accent", dest)
    );
  },
  async run(params, ctx) {
    const rawSrc = String(params.source ?? "");
    const rawDest = String(params.dest ?? "");
    if (!rawSrc || !rawDest) return { line: "mv: source and dest are required", isError: true };
    const src = resolvePath(ctx.cwd, rawSrc);
    let dest = resolvePath(ctx.cwd, rawDest);
    if (await isDirectory(dest)) dest = path.join(dest, path.basename(src));

    // The gates now evaluate `dest` (see registerDestinationGating), so guard
    // the source ourselves: deny globs, plus block an external source outright
    // (we cannot prompt from here, unlike the gated destination).
    if (pathPolicyDenies(src))
      return { line: `mv: source is blocked by the permission policy: ${src}`, isError: true };
    if (externalSourceBlocked(ctx.cwd, src))
      return { line: `mv: source is outside the working directory and not allowed by policy: ${src}`, isError: true };
    if (pathPolicyDenies(dest))
      return { line: `mv: destination is blocked by the permission policy: ${dest}`, isError: true };
    if (!(await exists(src))) return { line: `mv: no such file: ${rawSrc}`, isError: true };

    try {
      await fs.rename(src, dest);
    } catch (err) {
      if ((err as NodeJS.ErrnoException).code === "EXDEV") {
        // Cross-device move: copy then remove the source.
        await fs.cp(src, dest, { recursive: true, force: true });
        await fs.rm(src, { recursive: true, force: true });
      } else {
        throw err;
      }
    }
    return {
      line: `moved ${displayPath(ctx.cwd, src)} → ${displayPath(ctx.cwd, dest)}`,
    };
  },
};

// ── rm ────────────────────────────────────────────────────────────────────
const rmParams = Type.Object({
  path: pathParam,
  recursive: Type.Optional(
    Type.Boolean({
      description: "Remove a directory and its contents recursively.",
    }),
  ),
  force: Type.Optional(
    Type.Boolean({
      description: "Ignore nonexistent paths.",
    }),
  ),
});

const rmTool: FileToolDef<typeof rmParams> = {
  name: "rm",
  label: "remove",
  description:
    "Delete a file or directory (directories need `recursive: true`).",
  parameters: rmParams,
  header(args, theme) {
    const p = typeof args.path === "string" ? args.path : "…";
    let flags = "";
    if (args.recursive === true) flags += theme.fg("warning", " -r");
    if (args.force === true) flags += theme.fg("warning", " -f");
    return theme.fg("accent", p) + flags;
  },
  async run(params, ctx) {
    const raw = String(params.path ?? "");
    if (!raw) return { line: "rm: path is required", isError: true };
    const target = resolvePath(ctx.cwd, raw);
    const recursive = params.recursive === true;
    const force = params.force === true;

    if (!force && !(await exists(target))) {
      return { line: `rm: no such file: ${raw}`, isError: true };
    }
    if (!recursive && (await isDirectory(target))) {
      return {
        line: `rm: ${raw} is a directory (set recursive: true to remove it)`,
        isError: true,
      };
    }
    await fs.rm(target, { recursive, force });
    return { line: `removed ${displayPath(ctx.cwd, target)}` };
  },
};

// ── cp ────────────────────────────────────────────────────────────────────
const cpParams = Type.Object({
  source: sourceParam,
  dest: Type.String({
    description:
      "Destination path. An existing directory means 'copy inside it'.",
  }),
  recursive: Type.Optional(
    Type.Boolean({ description: "Copy directories recursively." }),
  ),
});

const cpTool: FileToolDef<typeof cpParams> = {
  name: "cp",
  label: "copy",
  description:
    "Copy a file or directory (directories need `recursive: true`).",
  parameters: cpParams,
  header(args, theme) {
    const src = typeof args.source === "string" ? args.source : "…";
    const dest = typeof args.dest === "string" ? args.dest : "…";
    const flags = args.recursive === true ? theme.fg("muted", " -r") : "";
    return (
      theme.fg("accent", src) +
      theme.fg("muted", " → ") +
      theme.fg("accent", dest) +
      flags
    );
  },
  async run(params, ctx) {
    const rawSrc = String(params.source ?? "");
    const rawDest = String(params.dest ?? "");
    if (!rawSrc || !rawDest) return { line: "cp: source and dest are required", isError: true };
    const src = resolvePath(ctx.cwd, rawSrc);
    let dest = resolvePath(ctx.cwd, rawDest);
    if (await isDirectory(dest)) dest = path.join(dest, path.basename(src));

    // The gates now evaluate `dest` (see registerDestinationGating), so guard
    // the source ourselves: deny globs, plus block an external source outright
    // (we cannot prompt from here, unlike the gated destination).
    if (pathPolicyDenies(src))
      return { line: `cp: source is blocked by the permission policy: ${src}`, isError: true };
    if (externalSourceBlocked(ctx.cwd, src))
      return { line: `cp: source is outside the working directory and not allowed by policy: ${src}`, isError: true };
    if (pathPolicyDenies(dest))
      return { line: `cp: destination is blocked by the permission policy: ${dest}`, isError: true };
    if (!(await exists(src))) return { line: `cp: no such file: ${rawSrc}`, isError: true };
    if (!(params.recursive === true) && (await isDirectory(src))) {
      return {
        line: `cp: ${rawSrc} is a directory (set recursive: true to copy it)`,
        isError: true,
      };
    }

    await fs.cp(src, dest, { recursive: params.recursive === true, force: true });
    return {
      line: `copied ${displayPath(ctx.cwd, src)} → ${displayPath(ctx.cwd, dest)}`,
    };
  },
};

// ── mkdir ─────────────────────────────────────────────────────────────────
const mkdirParams = Type.Object({
  path: pathParam,
  parents: Type.Optional(
    Type.Boolean({
      description: "Like `mkdir -p`. Defaults to true.",
    }),
  ),
});

const mkdirTool: FileToolDef<typeof mkdirParams> = {
  name: "mkdir",
  label: "make dir",
  description:
    "Create a directory. By default parents are created and an existing " +
    "target is not an error.",
  parameters: mkdirParams,
  header(args, theme) {
    const p = typeof args.path === "string" ? args.path : "…";
    const flags = args.parents === false ? "" : theme.fg("muted", " -p");
    return theme.fg("accent", p) + flags;
  },
  async run(params, ctx) {
    const raw = String(params.path ?? "");
    if (!raw) return { line: "mkdir: path is required", isError: true };
    const target = resolvePath(ctx.cwd, raw);
    const parents = params.parents !== false;
    if (!parents && (await exists(target))) {
      return { line: `mkdir: already exists: ${raw}`, isError: true };
    }
    await fs.mkdir(target, { recursive: parents });
    return { line: `created ${displayPath(ctx.cwd, target)}` };
  },
};

// ── destination gating ──────────────────────────────────────────────────
// Re-aim the shared `path` + `external_directory` gates at the WRITE TARGET.
//
// The gates extract one path per tool from `input.path` by default. mv/cp name
// their paths `source`/`dest`, so without help the gates would see neither.
// Register a `dest` extractor so the destination is the gated path: an
// external-directory destination then raises a real approval prompt (parity
// with `write`), and the `path` deny globs cover the destination directory.
// The source keeps its deny-glob protection via the explicit `pathPolicyDenies`
// checks in each tool's run().
function registerDestinationGating(pi: ExtensionAPI): void {
  const disposers: Array<() => void> = [];

  const register = (): void => {
    if (disposers.length) return; // already registered this generation
    const svc = getPermissionsService();
    if (typeof svc?.registerToolAccessExtractor !== "function") return;
    for (const tool of ["mv", "cp"]) {
      try {
        disposers.push(
          svc.registerToolAccessExtractor(tool, (input) => {
            const dest = input.dest;
            // Return the raw string; the gate resolves it against the session
            // cwd and expands `~`, at parity with the `input.path` convention.
            return typeof dest === "string" && dest.length > 0
              ? dest
              : undefined;
          }),
        );
      } catch {
        // Name already claimed (e.g. a racing re-register) — leave it be.
      }
    }
  };

  // The service publishes at session_start; the ready broadcast fires just
  // after. Register on both for load-order robustness, guarded against the
  // double-registration throw above.
  pi.events.on("permissions:ready", register);
  pi.on("session_start", () => register());

  pi.on("session_shutdown", () => {
    for (const dispose of disposers.splice(0)) {
      try {
        dispose();
      } catch {
        // best-effort teardown
      }
    }
  });
}

export default function fileToolsExtension(pi: ExtensionAPI): void {
  registerFileTool(pi, mvTool);
  registerFileTool(pi, rmTool);
  registerFileTool(pi, cpTool);
  registerFileTool(pi, mkdirTool);

  registerDestinationGating(pi);
}
