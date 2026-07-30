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
//   - Every tool exposes its primary target as `input.path`, which the
//     permission system extracts automatically. So the shared `path` deny
//     globs (*.age, **/.ssh/**, …) protect the target for free, and — since
//     these tool names are NOT in the `allow` list — each call falls through
//     to the `"*" = "ask"` default and is confirmed by the user.
//   - `mv`/`cp` take a second path (`dest`) that the built-in extractor
//     cannot see. We defend that surface ourselves by asking the permission
//     service whether the resolved destination is a denied `path` before
//     touching the filesystem.
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
interface PermissionsService {
  checkPermission(surface: string, value?: string): PermissionCheckResult;
}

function getPermissionsService(): PermissionsService | undefined {
  return (globalThis as Record<symbol, unknown>)[SERVICE_KEY] as
    | PermissionsService
    | undefined;
}

/**
 * Refuse a destination the permission policy denies on the `path` surface.
 * The built-in access-intent extractor only sees `input.path` (the source),
 * so mv/cp destinations would otherwise bypass the deny globs. Returns an
 * error string when the destination is denied, or `undefined` to proceed.
 * Fails open only when the service is unavailable (mirrors the graceful
 * degradation the cross-extension API prescribes).
 */
function destinationDenied(dest: string): string | undefined {
  try {
    const svc = getPermissionsService();
    if (!svc) return undefined;
    if (svc.checkPermission("path", dest).state === "deny") {
      return `Destination is blocked by the permission policy: ${dest}`;
    }
  } catch {
    // Never let a policy-check failure crash the tool.
  }
  return undefined;
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
  promptSnippet: string;
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
    promptSnippet: def.promptSnippet,
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
  description:
    "Filesystem path. Relative paths resolve against the session working " +
    "directory; a leading ~ expands to your home directory.",
});

// ── mv ────────────────────────────────────────────────────────────────────
const mvParams = Type.Object({
  path: pathParam,
  dest: Type.String({
    description:
      "Destination path. If it names an existing directory, the source is " +
      "moved inside it (keeping its basename), matching `mv` semantics.",
  }),
});

const mvTool: FileToolDef<typeof mvParams> = {
  name: "mv",
  label: "move",
  description:
    "Move or rename a file or directory. If the destination is an existing " +
    "directory the source is moved inside it. Works across filesystems.",
  promptSnippet: "Use mv to move/rename a file or directory.",
  parameters: mvParams,
  header(args, theme) {
    const src = typeof args.path === "string" ? args.path : "…";
    const dest = typeof args.dest === "string" ? args.dest : "…";
    return (
      theme.fg("accent", src) +
      theme.fg("muted", " → ") +
      theme.fg("accent", dest)
    );
  },
  async run(params, ctx) {
    const rawSrc = String(params.path ?? "");
    const rawDest = String(params.dest ?? "");
    if (!rawSrc || !rawDest) return { line: "mv: path and dest are required", isError: true };
    const src = resolvePath(ctx.cwd, rawSrc);
    let dest = resolvePath(ctx.cwd, rawDest);
    if (await isDirectory(dest)) dest = path.join(dest, path.basename(src));

    const denied = destinationDenied(dest);
    if (denied) return { line: `mv: ${denied}`, isError: true };
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
      description:
        "Remove directories and their contents recursively. Required to " +
        "delete a non-empty directory.",
    }),
  ),
  force: Type.Optional(
    Type.Boolean({
      description: "Ignore nonexistent paths and never error on missing files.",
    }),
  ),
});

const rmTool: FileToolDef<typeof rmParams> = {
  name: "rm",
  label: "remove",
  description:
    "Delete a file or directory. Deleting a directory requires " +
    "`recursive: true`. Use `force: true` to ignore missing paths.",
  promptSnippet:
    "Use rm to delete a file or directory (set recursive to remove a folder).",
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
  path: pathParam,
  dest: Type.String({
    description:
      "Destination path. If it names an existing directory, the source is " +
      "copied inside it (keeping its basename), matching `cp` semantics.",
  }),
  recursive: Type.Optional(
    Type.Boolean({
      description: "Copy directories recursively. Required to copy a folder.",
    }),
  ),
});

const cpTool: FileToolDef<typeof cpParams> = {
  name: "cp",
  label: "copy",
  description:
    "Copy a file or directory. Copying a directory requires " +
    "`recursive: true`. If the destination is an existing directory the " +
    "source is copied inside it.",
  promptSnippet:
    "Use cp to copy a file or directory (set recursive to copy a folder).",
  parameters: cpParams,
  header(args, theme) {
    const src = typeof args.path === "string" ? args.path : "…";
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
    const rawSrc = String(params.path ?? "");
    const rawDest = String(params.dest ?? "");
    if (!rawSrc || !rawDest) return { line: "cp: path and dest are required", isError: true };
    const src = resolvePath(ctx.cwd, rawSrc);
    let dest = resolvePath(ctx.cwd, rawDest);
    if (await isDirectory(dest)) dest = path.join(dest, path.basename(src));

    const denied = destinationDenied(dest);
    if (denied) return { line: `cp: ${denied}`, isError: true };
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
      description:
        "Create parent directories as needed and don't error if the target " +
        "already exists (like `mkdir -p`). Defaults to true.",
    }),
  ),
});

const mkdirTool: FileToolDef<typeof mkdirParams> = {
  name: "mkdir",
  label: "make dir",
  description:
    "Create a directory. By default (`parents: true`) intermediate " +
    "directories are created and an existing target is not an error.",
  promptSnippet: "Use mkdir to create a directory (parents created by default).",
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

export default function fileToolsExtension(pi: ExtensionAPI): void {
  registerFileTool(pi, mvTool);
  registerFileTool(pi, rmTool);
  registerFileTool(pi, cpTool);
  registerFileTool(pi, mkdirTool);
}
