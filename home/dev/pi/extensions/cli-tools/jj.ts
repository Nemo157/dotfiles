import type { CliToolDef } from "./shared";

export const jjTools: CliToolDef[] = [
  {
    name: "jj-status",
    label: "jj status",
    description: "Show working copy status via jj (jujutsu).",
    command: "jj",
    baseArgs: ["status"],
    promptSnippet: "Use jj-status to see the current jj working copy state.",
  },
  {
    name: "jj-diff",
    label: "jj diff",
    description:
      "Show the diff of the current jj working copy. Optional extra args " +
      "(e.g. a path or `-r <rev>`) can be passed via `args`.",
    command: "jj",
    baseArgs: ["diff"],
    acceptArgs: true,
    promptSnippet: "Use jj-diff to inspect current jj changes.",
  },
  {
    name: "jj-log",
    label: "jj log",
    description:
      "Show recent jj commits. Defaults to the last 20 entries. Extra args " +
      "(e.g. `-r <revset>`) can be passed via `args`.",
    command: "jj",
    baseArgs: ["log", "--limit", "20"],
    acceptArgs: true,
  },
];
