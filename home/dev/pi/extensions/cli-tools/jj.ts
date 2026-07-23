import { Type } from "typebox";
import { expandTilde, type StructuredCliToolDef } from "./shared";

// jj-status --------------------------------------------------------------

const jjStatusParams = Type.Object({});

const jjStatus: StructuredCliToolDef<typeof jjStatusParams> = {
  name: "jj-status",
  label: "jj status",
  command: "jj",
  description: "Show working copy status via jj (jujutsu).",
  promptSnippet: "Use jj-status to see the current jj working copy state.",
  parameters: jjStatusParams,
  buildArgs() {
    return ["status"];
  },
};

// jj-diff ----------------------------------------------------------------

const jjDiffParams = Type.Object({
  revision: Type.Optional(
    Type.String({
      description: "Show diff of this single revision (-r <rev>).",
    }),
  ),
  from: Type.Optional(
    Type.String({
      description: "Show changes from this revision (--from <rev>).",
    }),
  ),
  to: Type.Optional(
    Type.String({
      description: "Show changes to this revision (--to <rev>).",
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
  git: Type.Optional(
    Type.Boolean({ description: "Use git-format diff output (--git)." }),
  ),
  contextLines: Type.Optional(
    Type.Integer({
      minimum: 0,
      maximum: 20,
      description: "Lines of context around each hunk (--context).",
    }),
  ),
});

const jjDiff: StructuredCliToolDef<typeof jjDiffParams> = {
  name: "jj-diff",
  label: "jj diff",
  command: "jj",
  description:
    "Show a jj diff. Defaults to the current working copy; narrow with " +
    "`revision` or `from`/`to`, and/or `path`.",
  promptSnippet: "Use jj-diff to inspect current jj changes.",
  parameters: jjDiffParams,
  buildArgs(p) {
    const args: string[] = ["diff"];
    if (p.revision !== undefined) args.push("-r", p.revision);
    if (p.from !== undefined) args.push("--from", p.from);
    if (p.to !== undefined) args.push("--to", p.to);
    if (p.stat) args.push("--stat");
    if (p.git) args.push("--git");
    if (p.contextLines !== undefined) {
      args.push("--context", String(p.contextLines));
    }
    args.push("--");
    if (p.path !== undefined) args.push(expandTilde(p.path));
    return args;
  },
};

// jj-log -----------------------------------------------------------------

const jjLogParams = Type.Object({
  revisions: Type.Optional(
    Type.String({
      description: "Revset to show (-r <revset>). Defaults to jj's default.",
    }),
  ),
  limit: Type.Optional(
    Type.Integer({
      minimum: 1,
      maximum: 1000,
      description: "Maximum number of commits to show (--limit). Default 20.",
    }),
  ),
  path: Type.Optional(
    Type.String({
      description:
        "Restrict log to commits touching this path. Passed after `--`.",
    }),
  ),
  reversed: Type.Optional(
    Type.Boolean({ description: "Show oldest commits first (--reversed)." }),
  ),
  noGraph: Type.Optional(
    Type.Boolean({
      description: "Disable the ASCII graph (--no-graph).",
    }),
  ),
  stat: Type.Optional(
    Type.Boolean({ description: "Include a diffstat per commit (--stat)." }),
  ),
});

const jjLog: StructuredCliToolDef<typeof jjLogParams> = {
  name: "jj-log",
  label: "jj log",
  command: "jj",
  description: "Show recent jj commits. Defaults to the last 20 entries.",
  parameters: jjLogParams,
  buildArgs(p) {
    const args: string[] = ["log", "--limit", String(p.limit ?? 20)];
    if (p.revisions !== undefined) args.push("-r", p.revisions);
    if (p.reversed) args.push("--reversed");
    if (p.noGraph) args.push("--no-graph");
    if (p.stat) args.push("--stat");
    args.push("--");
    if (p.path !== undefined) args.push(expandTilde(p.path));
    return args;
  },
};

export const jjTools = [jjStatus, jjDiff, jjLog];
