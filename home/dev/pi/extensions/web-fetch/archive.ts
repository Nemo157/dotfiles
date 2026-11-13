// Archive support for the web-fetch extension, built on libarchive's
// `bsdtar` / `bsdcat` (paths come from the extension config; the Nix module
// pins them to the store).
//
// Two shapes of "archive" are handled:
//
//   container   zip / tar / 7z, optionally compressed (tar.gz, tar.xz, …).
//               Unpacked into `<cache>/<key>/archive/`; the agent gets a
//               file listing and browses the tree with read/rg/fd, or asks
//               for one member's extraction via the `member` parameter.
//   compressed  a single gzip / bzip2 / xz / zstd stream that is *not* a
//               container (e.g. `notes.txt.gz`). Decompressed with bsdcat
//               into the cache and then run through the normal HTML / PDF /
//               text pipeline.
//
// Only zip / tar / 7z (detected by magic bytes, for compressed input in the
// decompressed stream's head) are handed to bsdtar, not everything
// libarchive can read.
//
// Safety: the archive is first listed (bsdtar's mtree writer, which streams
// the whole archive without writing anything) and refused if its declared
// uncompressed size or entry count exceeds the configured limits. Headers
// can lie (zip / 7z sizes), so extraction does not read the archive
// directly: one bsdtar re-encodes it as a pax tar stream, which always
// carries exactly the declared sizes, through a byte-counting pipe into a
// second bsdtar that extracts it; the pipe is cut once the stream exceeds
// the size limit. bsdtar's default extraction checks reject `..`
// components, absolute paths and writes through symlinks; after extraction
// anything that is not a regular file or directory (symlinks, fifos, …) is
// deleted so nothing in the cache can point outside it, and the owner is
// granted access to everything left (archives may carry read-only or
// unreadable modes).

import { spawn, type ChildProcess } from "node:child_process";
import {
  chmodSync,
  closeSync,
  createWriteStream,
  existsSync,
  lstatSync,
  mkdirSync,
  openSync,
  readdirSync,
  readSync,
  realpathSync,
  renameSync,
  rmSync,
  statSync,
} from "node:fs";
import { join, relative, resolve, sep } from "node:path";
import { Writable } from "node:stream";
import { finished } from "node:stream/promises";

import { removeTree } from "./cache";

export type ContainerKind = "zip" | "tar" | "7z";
export type CompressionKind = "gzip" | "bzip2" | "xz" | "zstd";
export type ArchiveKind = ContainerKind | CompressionKind;

export interface ArchiveLimits {
  bsdtar: string;
  bsdcat: string;
  /** Maximum total uncompressed size (bytes). */
  maxBytes: number;
  /** Maximum number of entries in a container. */
  maxEntries: number;
}

const COMPRESSIONS: readonly string[] = ["gzip", "bzip2", "xz", "zstd"];

export function isCompression(kind: ArchiveKind): kind is CompressionKind {
  return COMPRESSIONS.includes(kind);
}

function startsWith(body: Buffer, bytes: number[], offset = 0): boolean {
  if (body.length < offset + bytes.length) return false;
  return bytes.every((b, i) => body[offset + i] === b);
}

/**
 * Detect an archive by magic bytes. Content types are deliberately ignored:
 * servers commonly send archives as application/octet-stream, and fetch may
 * already have undone a gzip Content-Encoding.
 */
export function archiveKind(body: Buffer): ArchiveKind | undefined {
  if (
    startsWith(body, [0x50, 0x4b, 0x03, 0x04]) ||
    startsWith(body, [0x50, 0x4b, 0x05, 0x06])
  )
    return "zip";
  if (startsWith(body, [0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c])) return "7z";
  if (
    body.length >= 262 &&
    body.subarray(257, 262).toString("latin1") === "ustar"
  )
    return "tar";
  if (startsWith(body, [0x1f, 0x8b])) return "gzip";
  if (startsWith(body, [0xfd, 0x37, 0x7a, 0x58, 0x5a, 0x00])) return "xz";
  if (startsWith(body, [0x28, 0xb5, 0x2f, 0xfd])) return "zstd";
  // "BZh" + block size digit + block / end-of-stream magic, so plain text
  // that happens to start with "BZh" is not misdetected.
  if (
    body.length >= 10 &&
    body.subarray(0, 3).toString("latin1") === "BZh" &&
    body[3] >= 0x31 &&
    body[3] <= 0x39 &&
    (startsWith(body, [0x31, 0x41, 0x59, 0x26, 0x53, 0x59], 4) ||
      startsWith(body, [0x17, 0x72, 0x45, 0x38, 0x50, 0x90], 4))
  )
    return "bzip2";
  return undefined;
}

/** File extension for the raw cache artifact of an archive. */
export function archiveExtension(kind: ArchiveKind): string {
  switch (kind) {
    case "gzip":
      return "gz";
    case "bzip2":
      return "bz2";
    case "zstd":
      return "zst";
    default:
      return kind;
  }
}

/** Strip a compression suffix from a file name (`.tgz` becomes `.tar`). */
export function innerName(name: string): string {
  if (/\.tgz$/i.test(name)) return name.replace(/\.tgz$/i, ".tar");
  return name.replace(/\.(gz|bz2|xz|zst|zstd)$/i, "");
}

// Document formats that are zip containers on the wire but are not useful to
// browse as an archive: the agent wants their text, not their XML parts.
// (Code bundles such as .jar / .whl / .vsix stay archives on purpose.)
const DOCUMENT_EXTENSIONS = new Set([
  "docx",
  "docm",
  "dotx",
  "dotm",
  "xlsx",
  "xlsm",
  "xltx",
  "xltm",
  "pptx",
  "pptm",
  "potx",
  "ppsx",
  "odt",
  "ods",
  "odp",
  "odg",
  "odf",
  "ott",
  "ots",
  "otp",
  "epub",
]);

const DOCUMENT_CONTENT_TYPES = [
  "application/vnd.openxmlformats-officedocument.",
  "application/vnd.ms-", // macro-enabled OOXML variants
  "application/vnd.oasis.opendocument.",
  "application/epub+zip",
];

/** Lower-cased extension of a file name, if it has one. */
export function nameExtension(name: string): string | undefined {
  return /\.([a-z0-9]{1,8})$/i.exec(name)?.[1]?.toLowerCase();
}

/** Whether a file is a zip-based document format (by name or content type). */
export function isZipDocument(name: string, contentType: string): boolean {
  const ext = nameExtension(name);
  if (ext && DOCUMENT_EXTENSIONS.has(ext)) return true;
  return DOCUMENT_CONTENT_TYPES.some((t) => contentType.startsWith(t));
}

/**
 * Archive kind to act on: the magic-byte detection, except that zip-based
 * documents (per their file name or content type) are not treated as
 * archives.
 */
export function archiveKindFor(
  body: Buffer,
  name: string,
  contentType: string,
): ArchiveKind | undefined {
  const kind = archiveKind(body);
  if (kind === "zip" && isZipDocument(name, contentType)) return undefined;
  return kind;
}

/** A command that could not start, exited non-zero, or was killed. */
class ProcessError extends Error {
  constructor(
    message: string,
    /** Killed by us (limit, abort, or a failing pipeline peer). */
    readonly killed: boolean,
  ) {
    super(message);
  }
}

interface Proc {
  child: ChildProcess;
  /** Resolves when the process exits with status 0, else rejects. */
  exited: Promise<void>;
}

/** Spawn a command with stdout/stderr piped (stderr is kept for errors). */
function start(
  cmd: string,
  args: string[],
  stdin: "ignore" | "pipe" = "ignore",
): Proc {
  const child = spawn(cmd, args, { stdio: [stdin, "pipe", "pipe"] });
  let err = "";
  child.stderr!.on("data", (chunk: Buffer) => {
    if (err.length < 4096) err += chunk.toString("utf8");
  });
  const exited = new Promise<void>((resolvePromise, reject) => {
    // Spawn failures (e.g. ENOENT) may not be followed by "close".
    child.on("error", (e) =>
      reject(new ProcessError(`cannot run ${cmd}: ${e.message}`, false)),
    );
    child.on("close", (code, sig) => {
      if (code === 0) return resolvePromise();
      reject(
        new ProcessError(
          err.trim() || `${cmd} exited with ${code ?? sig}`,
          child.killed,
        ),
      );
    });
  });
  // Callers that stop early never await this; avoid unhandled rejections.
  exited.catch(() => {});
  return { child, exited };
}

/**
 * Stream `proc`'s stdout into `sink` (with backpressure), killing it once
 * more than `limit` bytes have passed or `signal` aborts. Resolves once
 * `proc` and all `peers` (e.g. the process reading the sink) exited
 * successfully and the sink has finished; on any failure everything is
 * killed first.
 */
async function pump(
  proc: Proc,
  sink: Writable,
  limit: number,
  signal?: AbortSignal,
  peers: Proc[] = [],
): Promise<void> {
  const procs = [proc, ...peers];
  let stopped = false;
  let ownFailure: Error | undefined;
  const stop = (reason?: Error) => {
    if (stopped) return;
    stopped = true;
    ownFailure = reason;
    for (const p of procs) p.child.kill("SIGKILL");
    sink.destroy();
  };
  const onAbort = () => stop(new Error("aborted"));
  if (signal?.aborted) onAbort();
  else signal?.addEventListener("abort", onAbort, { once: true });

  const out = proc.child.stdout!;
  let bytes = 0;
  out.on("data", (chunk: Buffer) => {
    if (stopped) return;
    bytes += chunk.byteLength;
    if (bytes > limit) {
      stop(new Error(`output exceeds the ${limit}-byte limit`));
      return;
    }
    if (!sink.write(chunk)) out.pause();
  });
  out.on("end", () => {
    if (!stopped) sink.end();
  });
  sink.on("drain", () => out.resume());

  const settled = await Promise.allSettled(
    [...procs.map((p) => p.exited), finished(sink)].map((p) =>
      p.catch((e: unknown) => {
        stop();
        throw e;
      }),
    ),
  );
  signal?.removeEventListener("abort", onAbort);
  if (ownFailure) throw ownFailure;
  const errors = settled.flatMap((r) =>
    r.status === "rejected" ? [r.reason as Error] : [],
  );
  if (errors.length === 0) return;
  // Prefer a process's own diagnostic over pipe errors and kills we caused.
  throw errors.find((e) => e instanceof ProcessError && !e.killed) ?? errors[0];
}

/** Run a command and collect its stdout, bounded by `limit` bytes. */
async function collect(
  cmd: string,
  args: string[],
  limit: number,
  signal?: AbortSignal,
): Promise<Buffer> {
  const chunks: Buffer[] = [];
  const sink = new Writable({
    write(chunk: Buffer, _encoding, callback) {
      chunks.push(chunk);
      callback();
    },
  });
  await pump(start(cmd, args), sink, limit, signal);
  return Buffer.concat(chunks);
}

/** The first `n` bytes of a command's stdout; it is killed once read. */
async function commandHead(
  cmd: string,
  args: string[],
  n: number,
  signal?: AbortSignal,
): Promise<Buffer> {
  if (signal?.aborted) throw new Error("aborted");
  const proc = start(cmd, args);
  const chunks: Buffer[] = [];
  let got = 0;
  const onAbort = () => proc.child.kill("SIGKILL");
  signal?.addEventListener("abort", onAbort, { once: true });
  proc.child.stdout!.on("data", (chunk: Buffer) => {
    if (got >= n) return;
    chunks.push(chunk);
    got += chunk.byteLength;
    if (got >= n) proc.child.kill("SIGKILL");
  });
  try {
    await proc.exited;
  } catch (err) {
    if (signal?.aborted) throw new Error("aborted");
    // Being killed once enough was read is expected.
    if (got < n) throw err;
  } finally {
    signal?.removeEventListener("abort", onAbort);
  }
  return Buffer.concat(chunks).subarray(0, n);
}

/** The first `n` bytes of a file (fewer if it is shorter). */
export function readFileHead(path: string, n: number): Buffer {
  const fd = openSync(path, "r");
  try {
    const buf = Buffer.alloc(n);
    return buf.subarray(0, readSync(fd, buf, 0, n, 0));
  } finally {
    closeSync(fd);
  }
}

interface Inventory {
  entries: number;
  totalBytes: number;
}

/**
 * Inventory a container without extracting it, via bsdtar's mtree writer,
 * enforcing the limits on the entry count and the declared total size.
 */
async function inventory(
  file: string,
  limits: ArchiveLimits,
  signal?: AbortSignal,
): Promise<Inventory> {
  const out = await collect(
    limits.bsdtar,
    ["-cf", "-", "--format=mtree", "--options=!all,type,size", `@${file}`],
    // Each mtree line is short; this bounds memory for huge entry counts.
    Math.max(limits.maxEntries * 1024, 1 << 20),
    signal,
  );
  let entries = 0;
  let totalBytes = 0;
  for (const line of out.toString("utf8").split("\n")) {
    if (!line || line.startsWith("#") || line.startsWith("/")) continue;
    // mtree escapes whitespace in paths, so fields split cleanly.
    const fields = line.trim().split(/\s+/);
    entries++;
    const size = fields.find((f) => f.startsWith("size="));
    if (size) totalBytes += Number(size.slice(5)) || 0;
  }
  if (entries > limits.maxEntries) {
    throw new Error(
      `archive has ${entries} entries (limit ${limits.maxEntries})`,
    );
  }
  if (totalBytes > limits.maxBytes) {
    throw new Error(
      `archive unpacks to ${totalBytes} bytes (limit ${limits.maxBytes})`,
    );
  }
  return { entries, totalBytes };
}

/**
 * Delete everything that is not a regular file or directory, and normalize
 * modes so the owner can read (files) / traverse and modify (directories)
 * everything, without setuid/setgid/sticky bits. Returns the number of
 * entries deleted.
 */
function sanitize(dir: string): number {
  let removed = 0;
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    const st = lstatSync(p);
    if (st.isDirectory()) {
      chmodSync(p, (st.mode & 0o777) | 0o700);
      removed += sanitize(p);
    } else if (st.isFile()) {
      chmodSync(p, (st.mode & 0o777) | 0o600);
    } else {
      rmSync(p, { force: true });
      removed++;
    }
  }
  return removed;
}

export interface Unpacked {
  /** Directory the archive was unpacked into. */
  dir: string;
  /** Directory to present as the archive root: `dir`, or its single
   *  top-level subdirectory (GitHub-style tarballs). */
  root: string;
  /** Number of non-regular entries (symlinks, …) that were dropped. */
  pruned: number;
}

/**
 * The container format to unpack, if any: `kind` itself for zip/tar/7z, or
 * for compressed input the format detected in the head of the decompressed
 * stream (undefined: a single compressed file).
 */
export async function containerKind(
  file: string,
  kind: ArchiveKind,
  limits: ArchiveLimits,
  signal?: AbortSignal,
): Promise<ContainerKind | undefined> {
  if (!isCompression(kind)) return kind;
  const head = await commandHead(limits.bsdcat, [file], 512, signal);
  const inner = archiveKind(head);
  return inner && !isCompression(inner) ? inner : undefined;
}

// Allowance per entry for the pax stream's headers and padding on top of
// the file data (ustar + pax extended header, long paths, 512-byte blocks).
const PAX_ENTRY_OVERHEAD = 8 * 1024;

/**
 * Unpack a container (see containerKind) into `dir`, which is wiped first.
 * The re-encoded tar stream is cut off once it exceeds the size limit plus
 * per-entry header overhead, so lying size headers cannot fill the disk.
 */
export async function unpack(
  file: string,
  dir: string,
  limits: ArchiveLimits,
  signal?: AbortSignal,
): Promise<Unpacked> {
  const inv = await inventory(file, limits, signal);
  removeTree(dir);
  mkdirSync(dir, { recursive: true });
  try {
    const producer = start(limits.bsdtar, [
      "-cf",
      "-",
      "--format=pax",
      `@${file}`,
    ]);
    const consumer = start(
      limits.bsdtar,
      ["-xf", "-", "-C", dir, "--no-same-owner", "--no-same-permissions"],
      "pipe",
    );
    consumer.child.stdout!.resume();
    const limit =
      limits.maxBytes + (inv.entries + 1) * PAX_ENTRY_OVERHEAD + (1 << 20);
    await pump(producer, consumer.child.stdin!, limit, signal, [consumer]);
    const pruned = sanitize(dir);
    return { dir, root: archiveRoot(dir), pruned };
  } catch (err) {
    removeTree(dir);
    throw new Error(`unpacking failed: ${(err as Error).message}`);
  }
}

/** Root to present for an unpacked archive (collapses a single top dir). */
export function archiveRoot(dir: string): string {
  const top = readdirSync(dir);
  if (top.length === 1) {
    const only = join(dir, top[0]);
    if (lstatSync(only).isDirectory()) return only;
  }
  return dir;
}

/**
 * Decompress a single compressed stream to `dest`, bounded by the size
 * limit. Output goes to a temporary file that is only renamed into place on
 * success, so `dest` never holds a partial result.
 */
export async function decompress(
  file: string,
  dest: string,
  limits: ArchiveLimits,
  signal?: AbortSignal,
): Promise<void> {
  const tmp = `${dest}.part`;
  try {
    await pump(
      start(limits.bsdcat, [file]),
      createWriteStream(tmp),
      limits.maxBytes,
      signal,
    );
    renameSync(tmp, dest);
  } catch (err) {
    rmSync(tmp, { force: true });
    throw new Error(`decompression failed: ${(err as Error).message}`);
  }
}

export interface Listing {
  /** Listing lines (directories end in `/`, files show their size). */
  lines: string[];
  files: number;
  totalBytes: number;
}

/** Walk an unpacked tree, depth-first, sorted. */
export function listTree(root: string, format: (n: number) => string): Listing {
  const lines: string[] = [];
  let files = 0;
  let totalBytes = 0;
  const walk = (dir: string) => {
    const names = readdirSync(dir).sort();
    for (const name of names) {
      const p = join(dir, name);
      const rel = relative(root, p).split(sep).join("/");
      const st = lstatSync(p);
      if (st.isDirectory()) {
        lines.push(`${rel}/`);
        walk(p);
      } else if (st.isFile()) {
        files++;
        totalBytes += st.size;
        lines.push(`${rel}  (${format(st.size)})`);
      }
    }
  };
  walk(root);
  return { lines, files, totalBytes };
}

export interface ResolvedMember {
  /** Absolute path of the member file. */
  path: string;
  /** Canonical member path relative to the root (`/`-separated), so that
   *  equivalent spellings (`./a//b`, `a/x/../b`) share cache entries. */
  name: string;
}

/**
 * Resolve a member path (relative to the presented archive root) to a
 * regular file inside it, refusing anything that escapes the root.
 */
export function resolveMember(root: string, member: string): ResolvedMember {
  const cleaned = member.replace(/^\.?\/+/, "");
  const p = resolve(root, cleaned);
  if (p !== root && !p.startsWith(root + sep)) {
    throw new Error(`member '${member}' is outside the archive`);
  }
  if (!existsSync(p))
    throw new Error(`member '${member}' not found in archive`);
  const real = realpathSync(p);
  const realRoot = realpathSync(root);
  if (!real.startsWith(realRoot + sep) || !statSync(real).isFile()) {
    throw new Error(`member '${member}' is not a regular file in the archive`);
  }
  return { path: real, name: relative(realRoot, real).split(sep).join("/") };
}
