// On-disk cache for the web-fetch extension.
//
// Layout (under the configured cache root):
//
//   <root>/<key>/meta.json      metadata about the fetch (url, status, …)
//   <root>/<key>/raw.<ext>      the downloaded body, verbatim
//   <root>/<key>/extract.txt    readability/plain-text extraction (extract mode)
//   <root>/<key>/prompt-<h>.txt small-model answer for one prompt (h = prompt hash)
//   <root>/<key>/archive/       unpacked container archive (zip/tar/7z)
//   <root>/<key>/listing.txt    full file listing of the unpacked archive
//   <root>/<key>/member-<h>.txt extraction of one archive member (h = path hash)
//   <root>/<key>/decompressed.<ext>  single decompressed file (.gz etc.)
//
// `key` is a content-addressed hash of the request (mode + url), so repeat
// fetches reuse the same directory. A fresh download clears its key's
// directory first (so derived files never go stale); otherwise eviction is
// manual.

import { createHash } from "node:crypto";
import {
  chmodSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";

export function hash(input: string): string {
  return createHash("sha256").update(input).digest("hex").slice(0, 16);
}

/**
 * Recursively remove `path`, first granting the owner rwx on directories if
 * a plain removal fails (unpacked archives may contain read-only dirs).
 */
export function removeTree(path: string): void {
  try {
    rmSync(path, { recursive: true, force: true });
    return;
  } catch {
    // Fall through: make directories writable and retry.
  }
  const grant = (p: string) => {
    let st;
    try {
      st = lstatSync(p);
    } catch {
      return;
    }
    if (!st.isDirectory()) return;
    try {
      chmodSync(p, (st.mode & 0o777) | 0o700);
      for (const name of readdirSync(p)) grant(join(p, name));
    } catch {
      // Best effort; the retry below reports any remaining failure.
    }
  };
  grant(path);
  rmSync(path, { recursive: true, force: true });
}

export interface CacheMeta {
  url: string;
  finalUrl: string;
  status: number;
  contentType: string;
  mode: "extract" | "raw";
  rawFile: string;
  /** File name hint (Content-Disposition, else URL); absent in old entries. */
  fileName?: string;
  extractFile?: string;
  title?: string;
  /** Directory (relative to the key dir) holding the unpacked archive. */
  archiveDir?: string;
  /** Number of symlinks/special files dropped when unpacking the archive. */
  archivePruned?: number;
  /** Titles of extracted archive members, by canonical member path. */
  memberTitles?: Record<string, string>;
  /** Decompressed single-file payload (relative to the key dir). */
  decompressedFile?: string;
  fetchedAt: number;
  rawBytes: number;
}

export class Cache {
  constructor(private readonly root: string) {}

  private dir(key: string): string {
    return join(this.root, key);
  }

  path(key: string, name: string): string {
    return join(this.dir(key), name);
  }

  private ensureDir(key: string): string {
    const dir = this.dir(key);
    mkdirSync(dir, { recursive: true });
    return dir;
  }

  /** Remove everything cached for `key`. */
  clear(key: string): void {
    removeTree(this.dir(key));
  }

  has(key: string, name: string): boolean {
    return existsSync(this.path(key, name));
  }

  writeBytes(key: string, name: string, data: Buffer): string {
    this.ensureDir(key);
    const path = this.path(key, name);
    writeFileSync(path, data);
    return path;
  }

  writeText(key: string, name: string, text: string): string {
    this.ensureDir(key);
    const path = this.path(key, name);
    writeFileSync(path, text, "utf8");
    return path;
  }

  readText(key: string, name: string): string | undefined {
    const path = this.path(key, name);
    return existsSync(path) ? readFileSync(path, "utf8") : undefined;
  }

  readBytes(key: string, name: string): Buffer | undefined {
    const path = this.path(key, name);
    return existsSync(path) ? readFileSync(path) : undefined;
  }

  readMeta(key: string): CacheMeta | undefined {
    const text = this.readText(key, "meta.json");
    if (!text) return undefined;
    try {
      return JSON.parse(text) as CacheMeta;
    } catch {
      return undefined;
    }
  }

  writeMeta(key: string, meta: CacheMeta): void {
    this.writeText(key, "meta.json", JSON.stringify(meta, null, 2));
  }
}
