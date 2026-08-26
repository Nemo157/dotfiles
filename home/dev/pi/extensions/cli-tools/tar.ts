// `tar`: bundle files from one directory into an archive in a pre-allowed
// cache directory.
//
// Why this shape (a single base `path` plus relative members):
//
//   - Permission gating. The pi permission system extracts ONE filesystem
//     path per tool call, from `input.path`. Naming the base directory
//     exactly `path` means the shared `path` deny globs (*.age, **/.ssh/**,
//     …) and the `external_directory` prompt apply for free, with no custom
//     access extractor. The `paths` members are then validated (not gated):
//     each must stay inside the base directory, including after symlink
//     resolution, and each is additionally checked against the `path` deny
//     policy. A fixed `--exclude` set backstops recursive sweeps, which
//     would otherwise pull a denied file in via its parent directory.
//
//   - Consistent internal structure. Every archive entry is
//     `<topLevel>/<path-relative-to-base>`, so the layout inside the archive
//     mirrors the layout on disk. `topLevel` defaults to the base
//     directory's own name, can be renamed, or dropped entirely ("").
//
// The archive lands in the cache directory from ./config.ts (default
// `$XDG_CACHE_HOME/pi/tar`), which the Nix module also lists in
// `pi-permission-system.piInfrastructureReadPaths` so follow-up reads (or an
// `upload`) of the archive don't trip the external-directory gate.
//
// Portability: only flags common to GNU tar and macOS bsdtar are used, plus
// one flavour-specific rename flag (`--transform` / `-s`) that is required
// only when `topLevel` differs from the base directory's name.

import { Type, type Static } from "typebox";
import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readdirSync,
  realpathSync,
  statSync,
} from "node:fs";
import {
  basename,
  dirname,
  isAbsolute,
  join,
  normalize,
  relative,
  resolve,
  sep,
} from "node:path";
import {
  asStringArray,
  buildDefaultSpec,
  clampForLlm,
  commandOutput,
  expandTilde,
  runCommand,
  type CliToolDef,
  type CliToolDetails,
  type CustomCliToolDef,
} from "./shared";
import { loadConfig } from "./config";

// ── permission service (dependency-free accessor) ──────────────────────────
// Same trick as file-tools/edit-toggle: read the Symbol.for-backed service
// off globalThis so this extension needs no package.json / node_modules.
const SERVICE_KEY = Symbol.for("@gotgenes/pi-permission-system:service");

interface PermissionsService {
  checkPermission(
    surface: string,
    value?: string,
  ): { state: "allow" | "deny" | "ask" };
}

/**
 * Whether the `path` policy denies `resolved` (the deny globs: *.age,
 * **\/.ssh/**, *.env, …). The built-in gate only sees the base directory, so
 * every member is checked here too. Fails open when the service is
 * unavailable — the gates are off in that case anyway.
 */
function pathPolicyDenies(resolved: string): boolean {
  try {
    const svc = (globalThis as Record<symbol, unknown>)[SERVICE_KEY] as
      | PermissionsService
      | undefined;
    if (!svc) return false;
    return svc.checkPermission("path", resolved).state === "deny";
  } catch {
    return false;
  }
}

// Backstop for recursive members: mirrors the `path` deny globs so a denied
// file can't ride along inside an archived parent directory. Supported by
// both GNU tar and bsdtar.
const EXCLUDES = [
  "*.age",
  ".env",
  ".env.*",
  ".ssh",
  ".gnupg",
  "id_rsa",
  "id_ed25519",
];

const TIMEOUT_MS = 120_000;

// Archive/prefix names are embedded in argv and in a filesystem path, so keep
// them to an obviously safe character set (this also makes `,` usable as the
// `--transform` separator).
const SAFE_SEGMENT = /^[A-Za-z0-9._][A-Za-z0-9._-]*$/;

/** Which rename flag this tar understands, probed once at registration. */
type TarFlavour = "gnu" | "bsd" | "unknown";

function probeTarFlavour(): TarFlavour | null {
  const version = commandOutput("tar", ["--version"]);
  if (version === null) return null;
  if (/GNU tar/i.test(version)) return "gnu";
  if (/bsdtar/i.test(version)) return "bsd";
  return "unknown";
}

const params = Type.Object({
  path: Type.Optional(
    Type.String({
      description:
        "Base directory to archive from; relative to cwd, `~` expands. " +
        "Defaults to the working directory. All archived files must live " +
        "inside it.",
    }),
  ),
  paths: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Files/directories to include, each given RELATIVE to `path`. " +
        "Directories are archived recursively. Omit to archive the whole " +
        "base directory.",
    }),
  ),
  topLevel: Type.Optional(
    Type.String({
      description:
        "Top-level directory name inside the archive. Defaults to the base " +
        "directory's own name; pass \"\" for no top-level directory (entries " +
        "then start at the members themselves).",
    }),
  ),
  name: Type.Optional(
    Type.String({
      description:
        "Archive file name without extension. Defaults to the top-level " +
        "directory name.",
    }),
  ),
  compression: Type.Optional(
    Type.Union([Type.Literal("gz"), Type.Literal("none")], {
      description: "Compression for the archive. Defaults to gzip.",
    }),
  ),
});

type TarParams = Static<typeof params>;

interface TarExtraDetails {
  tar: {
    archivePath: string;
    entryCount: number;
    byteSize: number;
  };
}

function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  const units = ["kB", "MB", "GB"];
  let value = n / 1024;
  let i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return `${value.toFixed(value < 10 ? 1 : 0)} ${units[i]}`;
}

/** Normalise a member path: no leading `./`, no trailing separator. */
function normaliseMember(raw: string): string {
  let m = normalize(raw.trim());
  while (m.startsWith(`.${sep}`)) m = m.slice(2);
  while (m.length > 1 && m.endsWith(sep)) m = m.slice(0, -1);
  return m;
}

/** Validate a `topLevel` / `name` value made of safe path segments. */
function checkSegments(value: string, what: string): void {
  for (const seg of value.split("/")) {
    if (!SAFE_SEGMENT.test(seg)) {
      throw new Error(
        `Invalid ${what} "${value}": each segment must match ${SAFE_SEGMENT}.`,
      );
    }
  }
}

interface Plan {
  /** Directory tar is invoked from (-C). */
  tarCwd: string;
  /** Names handed to tar, already carrying the desired prefix. */
  entries: string[];
  /** Rename flag needed because `topLevel` differs from the physical name. */
  renameArgs: string[];
}

/**
 * Entry names for a whole-directory archive taken from inside the base: the
 * immediate children rather than `.`, so entries read `foo` instead of
 * `./foo` (and so a rename transform doesn't have to strip the `./`).
 */
function childrenOf(base: string): string[] {
  const kids = readdirSync(base);
  if (kids.length === 0) {
    throw new Error(`Base directory is empty, nothing to archive: ${base}`);
  }
  return kids;
}

function buildPlan(
  base: string,
  members: string[],
  topLevel: string,
  flavour: TarFlavour,
): Plan {
  const physical = basename(base);

  // No top-level directory: archive members as-is, relative to the base.
  if (topLevel === "") {
    return {
      tarCwd: base,
      entries: members.length > 0 ? members : childrenOf(base),
      renameArgs: [],
    };
  }

  // Top-level name equals the directory's own name: run from the parent and
  // let the physical layout supply the prefix. Fully portable.
  if (topLevel === physical) {
    return {
      tarCwd: dirname(base),
      entries:
        members.length > 0
          ? members.map((m) => `${physical}/${m}`)
          : [physical],
      renameArgs: [],
    };
  }

  // Renamed top-level directory: rewrite entry names on the fly. Symlink
  // TARGETS are deliberately left alone (GNU's `rh` flags; bsdtar's default).
  if (flavour === "gnu") {
    return {
      tarCwd: base,
      entries: members.length > 0 ? members : childrenOf(base),
      renameArgs: [`--transform=s,^,${topLevel}/,rh`],
    };
  }
  if (flavour === "bsd") {
    return {
      tarCwd: base,
      entries: members.length > 0 ? members : childrenOf(base),
      renameArgs: ["-s", `,^,${topLevel}/,`],
    };
  }
  throw new Error(
    `This tar does not support renaming the top-level directory. ` +
      `Omit topLevel (uses "${physical}") or set topLevel to "" or ` +
      `"${physical}".`,
  );
}

function makeTarTool(flavour: TarFlavour): CustomCliToolDef<typeof params> {
  const tool: CustomCliToolDef<typeof params> = {
    name: "tar",
    label: "tar",
    command: "tar",
    partialLabel: "Archiving…",
    description:
      "Bundle files from one base directory into a tar archive, written to " +
      "a pre-allowed cache directory (the returned path can be read or " +
      "uploaded directly). Members are given relative to the base " +
      "directory and keep their on-disk structure inside the archive.",
    timeoutMs: TIMEOUT_MS,
    parameters: params,
    displayArgs(p) {
      const args = ["-c", "-f", "<cache>/…"];
      if ((p.compression ?? "gz") === "gz") args.splice(1, 0, "-z");
      args.push("-C", p.path ?? ".");
      for (const m of asStringArray(p.paths)) args.push(m);
      return args;
    },
    async run(p: TarParams, ctx) {
      const { tarCacheDir } = loadConfig();

      // ── base directory ────────────────────────────────────────────────
      const base = resolve(ctx.cwd, expandTilde(p.path ?? "."));
      if (!existsSync(base) || !statSync(base).isDirectory()) {
        throw new Error(`Base path is not an existing directory: ${base}`);
      }
      if (basename(base) === "") {
        throw new Error("Refusing to archive the filesystem root.");
      }
      if (pathPolicyDenies(base)) {
        throw new Error(`Access to ${base} is denied by policy.`);
      }
      const baseReal = realpathSync(base);

      // ── members ───────────────────────────────────────────────────────
      const members: string[] = [];
      for (const raw of asStringArray(p.paths)) {
        if (raw.trim() === "") continue;
        const m = normaliseMember(raw);
        if (isAbsolute(m) || m.startsWith("~")) {
          throw new Error(
            `Member "${raw}" must be relative to the base directory (${base}).`,
          );
        }
        if (m === ".." || m.startsWith(`..${sep}`)) {
          throw new Error(`Member "${raw}" escapes the base directory.`);
        }
        const abs = resolve(base, m);
        if (!existsSync(abs)) {
          throw new Error(`No such file under ${base}: ${m}`);
        }
        // Symlink escape: the resolved location must still be inside the
        // (resolved) base directory.
        const real = realpathSync(abs);
        const rel = relative(baseReal, real);
        if (rel !== "" && (rel === ".." || rel.startsWith(`..${sep}`) || isAbsolute(rel))) {
          throw new Error(
            `Member "${raw}" resolves outside the base directory (${real}).`,
          );
        }
        if (pathPolicyDenies(abs)) {
          throw new Error(`Access to ${abs} is denied by policy.`);
        }
        members.push(m);
      }

      // ── naming ────────────────────────────────────────────────────────
      const physical = basename(base);
      const topLevel = p.topLevel === undefined ? physical : p.topLevel.trim();
      // Only a *renamed* top level ends up in argv as a rename expression;
      // the physical name is just a path component tar already handles.
      if (topLevel !== "" && topLevel !== physical) {
        checkSegments(topLevel, "topLevel");
      }

      let name: string;
      if (p.name?.trim()) {
        name = basename(p.name.trim()).replace(/\.tar(\.gz)?$/i, "");
        checkSegments(name, "name");
      } else {
        // Derived from the directory / top-level name: sanitise rather than
        // reject, so an awkward directory name still produces an archive.
        const derived = (topLevel !== "" ? topLevel.split("/").pop()! : physical)
          .replace(/\.tar(\.gz)?$/i, "")
          .replace(/[^A-Za-z0-9._-]/g, "-")
          .replace(/^[-]+/, "");
        name = SAFE_SEGMENT.test(derived) ? derived : "archive";
      }

      const gzip = (p.compression ?? "gz") === "gz";
      const ext = gzip ? ".tar.gz" : ".tar";

      // ── output location (content-addressed by the request) ────────────
      const key = createHash("sha256")
        .update(JSON.stringify({ base, members, topLevel, name, gzip }))
        .digest("hex")
        .slice(0, 16);
      const outDir = join(tarCacheDir, key);
      mkdirSync(outDir, { recursive: true });
      const archive = join(outDir, `${name}${ext}`);

      // ── invoke tar ────────────────────────────────────────────────────
      const plan = buildPlan(base, members, topLevel, flavour);
      const args = [
        "--create",
        "--verbose",
        ...(gzip ? ["--gzip"] : []),
        ...EXCLUDES.map((e) => `--exclude=${e}`),
        ...plan.renameArgs,
        "--file",
        archive,
        "-C",
        plan.tarCwd,
        "--",
        ...plan.entries,
      ];

      const r = await runCommand("tar", args, {
        cwd: ctx.cwd,
        signal: ctx.signal,
        timeoutMs: TIMEOUT_MS,
      });
      if (r.timedOut) throw new Error(`tar timed out after ${TIMEOUT_MS}ms.`);
      if (r.code !== 0) {
        const detail = (r.stderr.trim() || r.stdout.trim() || "no output").trim();
        throw new Error(`tar failed (exit ${r.code}): ${detail}`);
      }

      // GNU tar sends the -v listing to stdout (archive is a file), bsdtar
      // to stderr. Take whichever produced it.
      const listingText = (r.stdout.trim() ? r.stdout : r.stderr).trimEnd();
      const listing = listingText.length > 0 ? listingText.split("\n") : [];
      const byteSize = statSync(archive).size;

      const header =
        `created ${archive}\n` +
        `${listing.length} entr${listing.length === 1 ? "y" : "ies"}, ` +
        `${formatBytes(byteSize)}`;

      return {
        content: clampForLlm(
          listing.length > 0 ? `${header}\n\n${listing.join("\n")}` : header,
        ),
        stdout: listing.join("\n"),
        details: {
          tar: { archivePath: archive, entryCount: listing.length, byteSize },
        },
      };
    },
    renderResult(result, opts, theme, rctx) {
      const spec = buildDefaultSpec(result, opts, theme, rctx);
      const details = result.details as
        | (CliToolDetails & Partial<TarExtraDetails>)
        | undefined;
      const t = details?.tar;
      if (t) {
        spec.summary =
          theme.fg(
            "success",
            `${t.entryCount} entr${t.entryCount === 1 ? "y" : "ies"}`,
          ) +
          theme.fg("dim", ` → ${t.archivePath} (${formatBytes(t.byteSize)})`);
      }
      return spec;
    },
  };
  return tool;
}

/**
 * Register the `tar` tool when a usable `tar` binary is present. The probe
 * doubles as a flavour check: renaming the archive's top-level directory
 * needs GNU's `--transform` or bsdtar's `-s`, and an unrecognised tar simply
 * rejects that one option at call time.
 */
export function getTarTools(): CliToolDef[] {
  const flavour = probeTarFlavour();
  if (flavour === null) return [];
  return [makeTarTool(flavour)];
}
