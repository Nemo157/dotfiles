import { Type } from "typebox";
import {
  asStringArray,
  expandTilde,
  type StructuredCliToolDef,
} from "./shared";

// jj-status --------------------------------------------------------------

const jjStatusParams = Type.Object({});

const jjStatus: StructuredCliToolDef<typeof jjStatusParams> = {
  name: "jj-status",
  label: "jj status",
  command: "jj",
  description:
    "Show jj (jujutsu) working copy status. Also snapshots the working " +
    "copy, which auto-tracks new files into the colocated git tree so nix " +
    "flake evaluation can see them.",
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
    Type.String({ description: "Restrict diff to this path." }),
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
      description: "Restrict log to commits touching this path.",
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

// jj-show ---------------------------------------------------------------

const jjShowParams = Type.Object({
  revision: Type.Optional(
    Type.String({
      description: "Revision to show (-r <rev>). Defaults to `@`.",
    }),
  ),
});

const jjShow: StructuredCliToolDef<typeof jjShowParams> = {
  name: "jj-show",
  label: "jj show",
  command: "jj",
  description:
    "Show a commit's full, untruncated description (jj-log truncates it to " +
    "one line).",
  parameters: jjShowParams,
  buildArgs(p) {
    return ["log", "--no-graph", "-T", "description", "-r", p.revision ?? "@"];
  },
};

// jj-describe -----------------------------------------------------------

const jjDescribeParams = Type.Object({
  message: Type.String({
    description: "Description to set on the revision (-m <message>).",
  }),
  revision: Type.Optional(
    Type.String({
      description: "Revision to describe (-r <rev>). Defaults to `@`.",
    }),
  ),
});

const jjDescribe: StructuredCliToolDef<typeof jjDescribeParams> = {
  name: "jj-describe",
  label: "jj describe",
  command: "jj",
  description:
    "Set a revision's description without closing it off; defaults to `@`. " +
    "Use only to retitle a non-@ revision \u2014 prefer `jj-commit` for the " +
    "working copy, since `jj-describe` leaves `@` open and later edits pile " +
    "onto it.",
  parameters: jjDescribeParams,
  buildArgs(p) {
    // `-m` on its own keeps jj non-interactive; `--no-edit` is a separate
    // mode that preserves the existing description and is incompatible
    // with `-m`.
    const args: string[] = ["describe", "-m", p.message];
    if (p.revision !== undefined) args.push("-r", p.revision);
    return args;
  },
};

// jj-commit -------------------------------------------------------------

const jjCommitParams = Type.Object({
  message: Type.String({
    description:
      "Description for the committed revision (-m <message>). Use markdown, " +
      "including inline code, in the title and body.",
  }),
  paths: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Paths to commit (relative to the working directory); other changes " +
        "are left behind in `@`. Omit to commit everything.",
    }),
  ),
});

const jjCommit: StructuredCliToolDef<typeof jjCommitParams> = {
  name: "jj-commit",
  label: "jj commit",
  command: "jj",
  description:
    "Commit the working copy with the given description and start a fresh " +
    "empty `@` on top. The default tool for 'commit what I just did': it " +
    "seals the revision so later edits land in a new one.",
  parameters: jjCommitParams,
  buildArgs(p) {
    const args: string[] = ["commit", "-m", p.message];
    const paths = asStringArray(p.paths);
    if (paths.length > 0) {
      args.push("--", ...paths);
    }
    return args;
  },
};

// jj-squash -------------------------------------------------------------

const jjSquashParams = Type.Object({
  from: Type.Optional(
    Type.String({
      description: "Source revision to squash from (--from <rev>).",
    }),
  ),
  into: Type.Optional(
    Type.String({
      description: "Destination revision to squash into (--into <rev>).",
    }),
  ),
  message: Type.Optional(
    Type.String({
      description:
        "Description for the destination revision (-m). Set this or " +
        "`useDestinationMessage`.",
    }),
  ),
  useDestinationMessage: Type.Optional(
    Type.Boolean({
      description:
        "Keep the destination's existing description (-u). Set this or " +
        "`message`.",
    }),
  ),
  keepEmptied: Type.Optional(
    Type.Boolean({
      description: "Keep the source revision even if it becomes empty.",
    }),
  ),
  paths: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Paths to squash (relative to the working directory); other changes " +
        "stay in the source revision. Omit to squash everything.",
    }),
  ),
});

const jjSquash: StructuredCliToolDef<typeof jjSquashParams> = {
  name: "jj-squash",
  label: "jj squash",
  command: "jj",
  description:
    "Squash changes from one revision into another. Defaults to squashing " +
    "the working copy into its parent; narrow with `from`/`into` and " +
    "`paths`. " +
    "Set exactly one of `message` or `useDestinationMessage`.",
  parameters: jjSquashParams,
  buildArgs(p) {
    const args: string[] = ["squash"];
    if (p.from !== undefined) args.push("--from", p.from);
    if (p.into !== undefined) args.push("--into", p.into);
    if ((p.message !== undefined) === Boolean(p.useDestinationMessage)) {
      throw new Error(
        "jj-squash: set exactly one of `message` or " +
          "`useDestinationMessage`.",
      );
    }
    if (p.message !== undefined) {
      args.push("-m", p.message);
    } else {
      args.push("--use-destination-message");
    }
    if (p.keepEmptied) args.push("--keep-emptied");
    const paths = asStringArray(p.paths);
    if (paths.length > 0) {
      args.push("--", ...paths);
    }
    return args;
  },
};

export const jjTools = [
  jjStatus,
  jjDiff,
  jjLog,
  jjShow,
  jjDescribe,
  jjCommit,
  jjSquash,
];
