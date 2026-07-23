import { Type } from "typebox";
import { expandTilde, type StructuredCliToolDef } from "./shared";

// git-status -------------------------------------------------------------

const gitStatusParams = Type.Object({
  path: Type.Optional(
    Type.String({
      description:
        "Restrict status to this path. Passed after `--` so it is never " +
        "parsed as a flag.",
    }),
  ),
  short: Type.Optional(
    Type.Boolean({ description: "Compact porcelain-ish output (-s)." }),
  ),
  branch: Type.Optional(
    Type.Boolean({
      description: "Include branch/tracking info with -s (-b).",
    }),
  ),
});

const gitStatus: StructuredCliToolDef<typeof gitStatusParams> = {
  name: "git-status",
  label: "git status",
  command: "git",
  description: "Show git status.",
  parameters: gitStatusParams,
  buildArgs(p) {
    const args: string[] = ["status"];
    if (p.short) args.push("-s");
    if (p.branch) args.push("-b");
    args.push("--");
    if (p.path !== undefined) args.push(expandTilde(p.path));
    return args;
  },
};

// git-diff ---------------------------------------------------------------

const gitDiffParams = Type.Object({
  staged: Type.Optional(
    Type.Boolean({
      description: "Show staged changes only (--staged / --cached).",
    }),
  ),
  revision: Type.Optional(
    Type.String({
      description:
        "Revspec to diff (e.g. `HEAD`, `main`, `abc..def`, `abc...def`).",
    }),
  ),
  path: Type.Optional(
    Type.String({
      description:
        "Restrict diff to this path. Passed after `--` so it is never " +
        "parsed as a flag.",
    }),
  ),
  stat: Type.Optional(
    Type.Boolean({ description: "Summarise as a diffstat (--stat)." }),
  ),
  nameOnly: Type.Optional(
    Type.Boolean({
      description: "List only changed file names (--name-only).",
    }),
  ),
  nameStatus: Type.Optional(
    Type.Boolean({
      description: "List changed files with status letters (--name-status).",
    }),
  ),
  contextLines: Type.Optional(
    Type.Integer({
      minimum: 0,
      maximum: 20,
      description: "Lines of context around each hunk (-U<n>).",
    }),
  ),
});

const gitDiff: StructuredCliToolDef<typeof gitDiffParams> = {
  name: "git-diff",
  label: "git diff",
  command: "git",
  description:
    "Show a git diff. Defaults to unstaged working-tree changes; use " +
    "`staged` for the index or `revision` to compare specific commits.",
  parameters: gitDiffParams,
  buildArgs(p) {
    const args: string[] = ["diff"];
    if (p.staged) args.push("--staged");
    if (p.stat) args.push("--stat");
    if (p.nameOnly) args.push("--name-only");
    if (p.nameStatus) args.push("--name-status");
    if (p.contextLines !== undefined) args.push(`-U${p.contextLines}`);
    if (p.revision !== undefined) args.push(p.revision);
    args.push("--");
    if (p.path !== undefined) args.push(expandTilde(p.path));
    return args;
  },
};

// git-log ----------------------------------------------------------------

const gitLogParams = Type.Object({
  limit: Type.Optional(
    Type.Integer({
      minimum: 1,
      maximum: 1000,
      description: "Maximum number of commits to show (-n). Default 20.",
    }),
  ),
  revision: Type.Optional(
    Type.String({
      description:
        "Revspec to log (e.g. `HEAD`, `main`, `abc..def`). Defaults to HEAD.",
    }),
  ),
  path: Type.Optional(
    Type.String({
      description:
        "Restrict log to commits touching this path. Passed after `--`.",
    }),
  ),
  oneline: Type.Optional(
    Type.Boolean({
      description: "One-line-per-commit format (--oneline). Default true.",
    }),
  ),
  stat: Type.Optional(
    Type.Boolean({ description: "Include a diffstat per commit (--stat)." }),
  ),
  patch: Type.Optional(
    Type.Boolean({ description: "Include full patches per commit (-p)." }),
  ),
  author: Type.Optional(
    Type.String({
      description: "Limit to commits whose author matches (--author).",
    }),
  ),
  grep: Type.Optional(
    Type.String({
      description: "Limit to commits whose message matches (--grep).",
    }),
  ),
});

const gitLog: StructuredCliToolDef<typeof gitLogParams> = {
  name: "git-log",
  label: "git log",
  command: "git",
  description: "Show recent git commits (oneline, 20 entries by default).",
  parameters: gitLogParams,
  buildArgs(p) {
    const args: string[] = ["log", "-n", String(p.limit ?? 20)];
    // Default to --oneline unless caller explicitly disables it, or asks for
    // stat/patch output where the multi-line format is more useful.
    const wantsOneline =
      p.oneline ?? !(p.stat === true || p.patch === true);
    if (wantsOneline) args.push("--oneline");
    if (p.stat) args.push("--stat");
    if (p.patch) args.push("-p");
    if (p.author !== undefined) args.push(`--author=${p.author}`);
    if (p.grep !== undefined) args.push(`--grep=${p.grep}`);
    if (p.revision !== undefined) args.push(p.revision);
    args.push("--");
    if (p.path !== undefined) args.push(expandTilde(p.path));
    return args;
  },
};

export const gitTools = [gitStatus, gitDiff, gitLog];
