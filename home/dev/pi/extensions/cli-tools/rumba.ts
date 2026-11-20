// rumba (https://github.com/veecle/rumba): what the user is looking at in
// rumba, the PR review TUI running next to the agent. Mirrors the Claude
// Code `rumba-focus` skill, but reads rumba's focus file directly instead of
// running `rumba focus`, so no rumba binary is needed on PATH.
//
// The file format is internal to rumba (rumba-core/src/focus.rs); this is a
// port of its `focus::read` and `Focus::text`, keep them in sync:
//
// - One file per session: `<state dir>/rumba/focus/<key>.json`, where the
//   key is `$RUMBA_SESSION` (the tmux window id, set by rumba's shell
//   integration and inherited from pi's environment) with `/` and `\`
//   replaced by `_`, or `default` if unset.
// - The state dir is the `dirs` crate's `state_dir()`, falling back to
//   `data_dir()` (macOS has no state dir).
// - The file holds the writer's PID; a file whose process is gone is stale
//   and ignored.
//
// Registered when rumba's state directory exists, i.e. rumba has run on
// this machine.

import { Type } from "typebox";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { CliToolDef, CustomCliToolDef } from "./shared";

interface FocusLine {
  prefix: string;
  text: string;
  old: number | null;
  new: number | null;
}

interface FocusComment {
  author: string;
  body: string;
  line: number | null;
  reply: boolean;
  resolved?: boolean;
}

interface FocusHunk {
  path: string;
  index: number;
  count: number;
  header: string;
  lines: FocusLine[];
  cursor: number;
  selection: [number, number] | null;
  comments: FocusComment[];
}

interface Focus {
  pid: number;
  repo: string;
  number: number;
  title: string;
  url: string;
  head_sha: string;
  commit: { sha: string; title: string } | null;
  hunk: FocusHunk | null;
}

/** rumba's base directory: `dirs::state_dir()`, else `dirs::data_dir()`. */
function stateDir(): string {
  const home = homedir();
  if (process.platform === "darwin") {
    return join(home, "Library", "Application Support");
  }
  const xdg = process.env.XDG_STATE_HOME;
  // `dirs` ignores relative XDG paths.
  return xdg?.startsWith("/") ? xdg : join(home, ".local", "state");
}

function rumbaDir(): string {
  return join(stateDir(), "rumba");
}

function sessionKey(): string {
  const key = process.env.RUMBA_SESSION;
  if (key === undefined || key.trim() === "") return "default";
  return key.replace(/[/\\]/g, "_");
}

function focusPath(): string {
  return join(rumbaDir(), "focus", `${sessionKey()}.json`);
}

function isRunning(pid: number): boolean {
  try {
    // Signal 0 only checks that the process exists.
    process.kill(pid, 0);
    return true;
  } catch (err) {
    // EPERM: it exists but belongs to someone else.
    return (err as NodeJS.ErrnoException).code === "EPERM";
  }
}

/** The focus of the rumba running in this session, if any. */
function readFocus(path: string): Focus | null {
  let text: string;
  try {
    text = readFileSync(path, "utf8");
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw err;
  }
  const focus = JSON.parse(text) as Focus;
  return isRunning(focus.pid) ? focus : null;
}

function short(sha: string): string {
  return sha.slice(0, 8);
}

function lineLabel(line: FocusLine | undefined): string {
  if (line === undefined) return "";
  if (line.new !== null) return `new line ${line.new}`;
  if (line.old !== null) return `old line ${line.old}`;
  return "line ?";
}

function position(hunk: FocusHunk): string {
  const sel = hunk.selection;
  if (sel !== null && sel[0] !== sel[1]) {
    return (
      `selected ${lineLabel(hunk.lines[sel[0]])} ` +
      `to ${lineLabel(hunk.lines[sel[1]])}`
    );
  }
  return lineLabel(hunk.lines[hunk.cursor]);
}

/** Rust's `str::lines`: no trailing empty line, `\r\n` accepted. */
function bodyLines(body: string): string[] {
  if (body === "") return [];
  return body.replace(/\r?\n$/, "").split(/\r?\n/);
}

function num(n: number | null): string {
  return (n === null ? "" : String(n)).padStart(5);
}

/** Port of rumba's `Focus::text`. */
function formatFocus(f: Focus): string {
  const view =
    f.commit === null
      ? "all changes"
      : `commit ${short(f.commit.sha)} "${f.commit.title}"`;
  const out = [
    `PR       ${f.repo}#${f.number} "${f.title}"`,
    `URL      ${f.url}`,
    `Head     ${f.head_sha}`,
    `View     ${view}`,
  ];
  const hunk = f.hunk;
  if (hunk === null) {
    out.push("", "This view has no changes.");
    return out.join("\n");
  }
  const rev = f.commit?.sha ?? f.head_sha;
  out.push(
    `File     ${hunk.path} (hunk ${hunk.index}/${hunk.count})`,
    `Cursor   ${position(hunk)}`,
    `Code     git fetch origin pull/${f.number}/head && ` +
      `git show ${rev}:${hunk.path}`,
    "",
    hunk.header,
  );
  hunk.lines.forEach((line, i) => {
    const sel = hunk.selection;
    const marker =
      i === hunk.cursor
        ? ">"
        : sel !== null && i >= sel[0] && i <= sel[1]
          ? "|"
          : " ";
    out.push(
      `${marker} ${num(line.old)} ${num(line.new)} ${line.prefix}${line.text}`,
    );
  });
  if (hunk.comments.length > 0) {
    out.push("", "Comments");
    for (const c of hunk.comments) {
      const indent = c.reply ? "    " : "  ";
      const at = c.line !== null ? ` on line ${c.line}` : "";
      const resolved = c.resolved && !c.reply ? " (resolved)" : "";
      out.push(`${indent}@${c.author}${at}${resolved}:`);
      for (const l of bodyLines(c.body)) out.push(`${indent}  ${l}`);
    }
  }
  return out.join("\n");
}

const focusParams = Type.Object({});

const rumbaFocus: CustomCliToolDef<typeof focusParams> = {
  name: "rumba-focus",
  label: "rumba focus",
  // Display only: the tool reads the focus file itself (see above).
  command: "rumba",
  description:
    "See what the user is looking at in rumba, the pull request review " +
    "tool running next to you: the PR, the file, the hunk with line " +
    "numbers, the cursor line (`>`) or visual selection (`|`), and the " +
    "review threads on the hunk. Use when the user points at something in " +
    'their review without naming it ("this", "here", "this hunk", "this ' +
    'line"). Fails when no review is open.',
  promptSnippet: "See what the user is looking at in their rumba PR review",
  promptGuidelines: [
    "Call rumba-focus each time the user points at something in their " +
      "rumba review, because the cursor moves between questions. If no " +
      "review is open, ask the user what they mean.",
    "The PR's code is at the revision in rumba-focus's `Code` line, " +
      "usually not the working copy: read it at that revision (or from " +
      "GitHub if the cwd isn't a clone of the PR's repository).",
  ],
  parameters: focusParams,
  displayArgs: () => ["focus"],
  async run() {
    const path = focusPath();
    const focus = readFocus(path);
    if (focus === null) {
      return {
        content:
          `No rumba review is open in this session ` +
          `(RUMBA_SESSION=${sessionKey()}).`,
        isError: true,
      };
    }
    return { content: formatFocus(focus) };
  },
};

/** Return the rumba tools when rumba has run on this machine. */
export function getRumbaTools(): CliToolDef[] {
  if (!existsSync(rumbaDir())) return [];
  return [rumbaFocus];
}
