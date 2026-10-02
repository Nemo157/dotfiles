import { Type } from "typebox";
import {
  asStringArray,
  expandTilde,
  type StructuredCliToolDef,
} from "./shared";

// Set on every tool that rewrites the repo, since concurrent jj operations
// race and produce divergent operations/commits. pi then runs the whole
// batch containing such a call sequentially, in the order the model emitted
// it, so the model can safely chain e.g. `jj-commit` + `jj-new` in one turn.
const SEQUENTIAL = "sequential" as const;

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
      description:
        "Revset to show (-r <revset>). Defaults to `trunk()..@` (the current " +
        "stack), hiding unrelated sibling branches.",
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
  description:
    "Show recent jj commits. Defaults to the last 20 entries of the current " +
    "stack (`trunk()..@`).",
  parameters: jjLogParams,
  buildArgs(p) {
    const args: string[] = ["log", "--limit", String(p.limit ?? 20)];
    args.push("-r", p.revisions ?? "trunk()..@");
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
  executionMode: SEQUENTIAL,
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
  executionMode: SEQUENTIAL,
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

// jj-new ----------------------------------------------------------------

const jjNewParams = Type.Object({
  revisions: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Parent revision(s) of the new change; several make a merge. " +
        "Defaults to `@`. Cannot be combined with `insertAfter`/" +
        "`insertBefore`.",
    }),
  ),
  insertAfter: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Insert the new change after these revision(s) (-A), rebasing " +
        "their children onto it. Combinable with `insertBefore`.",
    }),
  ),
  insertBefore: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Insert the new change before these revision(s) (-B), rebasing " +
        "them onto it. Combinable with `insertAfter`.",
    }),
  ),
  message: Type.Optional(
    Type.String({
      description: "Description for the new change (-m <message>).",
    }),
  ),
  noEdit: Type.Optional(
    Type.Boolean({
      description:
        "Create the change without making it the working copy (--no-edit).",
    }),
  ),
});

const jjNew: StructuredCliToolDef<typeof jjNewParams> = {
  name: "jj-new",
  label: "jj new",
  command: "jj",
  description:
    "Create a new empty change and (unless `noEdit`) make it the working " +
    "copy `@`. Use it to move around history: `jj-new` on top of an earlier " +
    "or conflicted revision, edit files, then `jj-squash` into the parent " +
    "to amend it (descendants rebase automatically). With `insertAfter`/" +
    "`insertBefore` it adds a new commit into the middle of a stack.",
  executionMode: SEQUENTIAL,
  parameters: jjNewParams,
  buildArgs(p) {
    const revisions = asStringArray(p.revisions);
    const after = asStringArray(p.insertAfter);
    const before = asStringArray(p.insertBefore);
    if (revisions.length > 0 && after.length + before.length > 0) {
      throw new Error(
        "jj-new: `revisions` cannot be combined with `insertAfter`/" +
          "`insertBefore`.",
      );
    }
    const args: string[] = ["new"];
    for (const r of after) args.push("-A", r);
    for (const r of before) args.push("-B", r);
    if (p.message !== undefined) args.push("-m", p.message);
    if (p.noEdit) args.push("--no-edit");
    if (revisions.length > 0) args.push("--", ...revisions);
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
  executionMode: SEQUENTIAL,
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

// jj-restore ------------------------------------------------------------

const jjRestoreParams = Type.Object({
  from: Type.Optional(
    Type.String({
      description:
        "Revision to restore file contents from (--from <rev>). Defaults to " +
        "the parent of `into`.",
    }),
  ),
  into: Type.Optional(
    Type.String({
      description: "Revision to restore into (--into <rev>). Defaults to `@`.",
    }),
  ),
  restoreDescendants: Type.Optional(
    Type.Boolean({
      description:
        "Preserve descendants' content instead of letting the restore " +
        "propagate into them (--restore-descendants).",
    }),
  ),
  paths: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Paths to restore (relative to the working directory). Set this or " +
        "`all`.",
    }),
  ),
  all: Type.Optional(
    Type.Boolean({
      description:
        "Restore every path. Set this or `paths`; required explicitly to " +
        "avoid accidentally wiping a revision.",
    }),
  ),
});

const jjRestore: StructuredCliToolDef<typeof jjRestoreParams> = {
  name: "jj-restore",
  label: "jj restore",
  command: "jj",
  description:
    "Restore paths in a revision from another revision. Defaults to " +
    "restoring `@` from its parent, i.e. discarding working-copy changes. " +
    "To undo a revision's changes use `from: \"X-\", into: \"X\"`. " +
    "Set exactly one of `paths` or `all`.",
  executionMode: SEQUENTIAL,
  parameters: jjRestoreParams,
  buildArgs(p) {
    const paths = asStringArray(p.paths);
    if ((paths.length > 0) === Boolean(p.all)) {
      throw new Error("jj-restore: set exactly one of `paths` or `all`.");
    }
    const args: string[] = ["restore"];
    if (p.from !== undefined) args.push("--from", p.from);
    if (p.into !== undefined) args.push("--into", p.into);
    if (p.restoreDescendants) args.push("--restore-descendants");
    if (paths.length > 0) args.push("--", ...paths.map(expandTilde));
    return args;
  },
};

// jj-rebase -------------------------------------------------------------

const jjRebaseParams = Type.Object({
  source: Type.Optional(
    Type.String({
      description:
        "Rebase this revision together with its descendants (-s <rev>). Set " +
        "this or `revisions`.",
    }),
  ),
  revisions: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Rebase only these revisions (-r); their children are reparented " +
        "onto their former parents. Set this or `source`.",
    }),
  ),
  onto: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "New parent(s) (--onto); several make a merge. Cannot be combined " +
        "with `insertAfter`/`insertBefore`.",
    }),
  ),
  insertAfter: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Insert after these revision(s) (-A), rebasing their children onto " +
        "the moved revisions. Combinable with `insertBefore`.",
    }),
  ),
  insertBefore: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Insert before these revision(s) (-B), rebasing them onto the moved " +
        "revisions. Combinable with `insertAfter`.",
    }),
  ),
  skipEmptied: Type.Optional(
    Type.Boolean({
      description:
        "Abandon commits that become empty after the rebase (--skip-emptied).",
    }),
  ),
});

const jjRebase: StructuredCliToolDef<typeof jjRebaseParams> = {
  name: "jj-rebase",
  label: "jj rebase",
  command: "jj",
  description:
    "Move revisions to new parents. Choose what to move with exactly one of " +
    "`source` (revision plus descendants) or `revisions` (just those, " +
    "children get reparented), and where with `onto` or `insertAfter`/" +
    "`insertBefore`. Conflicts are recorded in the commits rather than " +
    "stopping the rebase.",
  executionMode: SEQUENTIAL,
  parameters: jjRebaseParams,
  buildArgs(p) {
    const revisions = asStringArray(p.revisions);
    const onto = asStringArray(p.onto);
    const after = asStringArray(p.insertAfter);
    const before = asStringArray(p.insertBefore);
    if ((p.source !== undefined) === (revisions.length > 0)) {
      throw new Error(
        "jj-rebase: set exactly one of `source` or `revisions`.",
      );
    }
    if ((onto.length > 0) === (after.length + before.length > 0)) {
      throw new Error(
        "jj-rebase: set either `onto` or `insertAfter`/`insertBefore`.",
      );
    }
    const args: string[] = ["rebase"];
    if (p.source !== undefined) args.push("-s", p.source);
    for (const r of revisions) args.push("-r", r);
    for (const r of onto) args.push("--onto", r);
    for (const r of after) args.push("-A", r);
    for (const r of before) args.push("-B", r);
    if (p.skipEmptied) args.push("--skip-emptied");
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
  jjNew,
  jjSquash,
  jjRestore,
  jjRebase,
];
