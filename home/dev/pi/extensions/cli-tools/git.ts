import type { CliToolDef } from "./shared";

export const gitTools: CliToolDef[] = [
  {
    name: "git-status",
    label: "git status",
    description: "Show git status (porcelain-friendly summary).",
    command: "git",
    baseArgs: ["status"],
  },
  {
    name: "git-diff",
    label: "git diff",
    description:
      "Show git diff. Extra args (path, `--staged`, revspec) can be passed " +
      "via `args`.",
    command: "git",
    baseArgs: ["diff"],
    acceptArgs: true,
  },
  {
    name: "git-log",
    label: "git log",
    description:
      "Show recent git commits (oneline, 20 entries by default). Extra args " +
      "can be passed via `args`.",
    command: "git",
    baseArgs: ["log", "--oneline", "-n", "20"],
    acceptArgs: true,
  },
];
