// On-disk cache for the web-fetch extension.
//
// Layout (under the configured cache root):
//
//   <root>/<key>/meta.json      metadata about the fetch (url, status, …)
//   <root>/<key>/raw.<ext>      the downloaded body, verbatim
//   <root>/<key>/extract.txt    readability/plain-text extraction (extract mode)
//   <root>/<key>/prompt-<h>.txt small-model answer for one prompt (h = prompt hash)
//
// `key` is a content-addressed hash of the request (mode + url), so repeat
// fetches reuse the same directory. Eviction is manual — nothing here ever
// deletes files.

import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";

export function hash(input: string): string {
  return createHash("sha256").update(input).digest("hex").slice(0, 16);
}

export interface CacheMeta {
  url: string;
  finalUrl: string;
  status: number;
  contentType: string;
  mode: "extract" | "raw";
  rawFile: string;
  extractFile?: string;
  title?: string;
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
