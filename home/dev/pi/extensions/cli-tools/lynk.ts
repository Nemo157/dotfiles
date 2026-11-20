// lynk wrappers (https://github.com/veecle/lynk): check and navigate the
// links between a repository's documentation and its code. Only the
// read-only commands are exposed; `export` writes a directory tree and is
// left out until there is a need for it.
//
// Registered when a `lynk` binary answers `--help` within a short timeout.
// The lynk repo's own dev shell wraps `cargo run --release`, which would
// fail that probe while it compiles; that is accepted, the tools target
// repositories using an installed lynk.
//
// No `path`/`--root` params: lynk finds the repository from `ctx.cwd`.

import { Type, type Static, type TSchema } from "typebox";
import {
  commandOk,
  type CliToolDef,
  type CustomCliToolDef,
  runCommand,
  type StructuredCliToolDef,
} from "./shared";
import { inGitRepo, inJjRepo } from "./vcs";

const TIMEOUT_MS = 60_000;

// `lynk context` re-ranks its matches through the external TypeSafe API
// when this is set; stripping it keeps the tool local.
const TYPESAFE_API_KEY = "TYPESAFE_API_KEY";

// --- lynk lint -----------------------------------------------------------

const lintParams = Type.Object({});

const lynkLint: StructuredCliToolDef<typeof lintParams> = {
  name: "lynk-lint",
  label: "lynk lint",
  command: "lynk",
  partialLabel: "Linting…",
  description:
    "Check every lynk link of the repository against the code. Run it " +
    "before finishing any change.",
  timeoutMs: TIMEOUT_MS,
  parameters: lintParams,
  buildArgs() {
    return ["lint"];
  },
};

// --- lynk resolve / backlinks --------------------------------------------

const queryParams = Type.Object({
  selector: Type.String({
    description:
      "The link's `provider.selector`, e.g. `markdown.section` or " +
      "`rust.module`.",
  }),
  arguments: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "The selector's arguments, one per element, never quoted. A file " +
        "left out matches every file.",
    }),
  ),
});

function queryArgs(command: string, p: Static<typeof queryParams>): string[] {
  return [command, "--", p.selector, ...(p.arguments ?? [])];
}

const lynkResolve: StructuredCliToolDef<typeof queryParams> = {
  name: "lynk-resolve",
  label: "lynk resolve",
  command: "lynk",
  description:
    "Resolve a lynk link to the spans it points at, with their first " +
    "line. Follow links with this instead of searching for names.",
  timeoutMs: TIMEOUT_MS,
  parameters: queryParams,
  buildArgs: (p) => queryArgs("resolve", p),
};

const lynkBacklinks: StructuredCliToolDef<typeof queryParams> = {
  name: "lynk-backlinks",
  label: "lynk backlinks",
  command: "lynk",
  description:
    "List every place linking to the spans a lynk link points at. Run it " +
    "before changing, moving or removing anything, and update the text at " +
    "every place it lists. `filesystem.file README.md` lists everything " +
    "referring to the README.",
  timeoutMs: TIMEOUT_MS,
  parameters: queryParams,
  buildArgs: (p) => queryArgs("backlinks", p),
};

// --- lynk context --------------------------------------------------------

const contextParams = Type.Object({
  query: Type.String({
    minLength: 1,
    description: "A few words describing the task, e.g. `comment parsing`.",
  }),
});

const lynkContext: StructuredCliToolDef<typeof contextParams> = {
  name: "lynk-context",
  label: "lynk context",
  command: "lynk",
  description:
    "List the documentation sections, decisions and comments matching a " +
    "few words, best first. Matches words rather than links, so it also " +
    "finds what nobody linked yet. Run it before starting a task.",
  timeoutMs: TIMEOUT_MS,
  unsetEnv: [TYPESAFE_API_KEY],
  parameters: contextParams,
  buildArgs(p) {
    return ["context", "--", ...p.query.split(/\s+/).filter(Boolean)];
  },
};

// --- lynk affected -------------------------------------------------------

const jjAffectedParams = Type.Object({
  revision: Type.Optional(
    Type.String({
      description: "Diff this single revision (-r <rev>). Defaults to `@`.",
    }),
  ),
  from: Type.Optional(
    Type.String({ description: "Diff from this revision (--from <rev>)." }),
  ),
  to: Type.Optional(
    Type.String({ description: "Diff to this revision (--to <rev>)." }),
  ),
});

const gitAffectedParams = Type.Object({
  from: Type.Optional(
    Type.String({
      description:
        "Diff the working tree against this commit. Defaults to `HEAD`.",
    }),
  ),
});

function jjDiffArgs(p: Static<typeof jjAffectedParams>): string[] {
  const args = ["diff", "--git"];
  if (p.revision !== undefined) args.push("-r", p.revision);
  if (p.from !== undefined) args.push("--from", p.from);
  if (p.to !== undefined) args.push("--to", p.to);
  return args;
}

function gitDiffArgs(p: Static<typeof gitAffectedParams>): string[] {
  return ["diff", p.from ?? "HEAD", "--"];
}

const AFFECTED_DESCRIPTION =
  "List every lynk link pointing at lines a diff changes: the text to " +
  "reread and update after a change. Lines are counted in the files as " +
  "the diff leaves them, so diff up to the files as they are now.";

function makeAffectedTool<T extends TSchema>(
  vcs: "jj" | "git",
  parameters: T,
  diffArgs: (p: Static<T>) => string[],
): CustomCliToolDef<T> {
  return {
    name: "lynk-affected",
    label: "lynk affected",
    command: vcs,
    description: `${AFFECTED_DESCRIPTION} Pipes \`${vcs} diff\` into it.`,
    timeoutMs: TIMEOUT_MS,
    parameters,
    displayPipeline: (p) => [
      [vcs, ...diffArgs(p)],
      ["lynk", "affected"],
    ],
    async run(p, ctx) {
      const opts = {
        cwd: ctx.cwd,
        signal: ctx.signal,
        timeoutMs: TIMEOUT_MS,
      };
      const diff = await runCommand(vcs, diffArgs(p), opts);
      if (diff.code !== 0) {
        return {
          content:
            diff.stderr.trim() ||
            `${vcs} diff failed (exit ${diff.code ?? "unknown"}).`,
          isError: true,
        };
      }
      if (diff.stdout.trim().length === 0) {
        return { content: "No changes in the diff." };
      }
      const lynk = await runCommand("lynk", ["affected"], {
        ...opts,
        stdin: diff.stdout,
      });
      const out = [lynk.stdout.trimEnd(), lynk.stderr.trimEnd()]
        .filter((s) => s.length > 0)
        .join("\n\n");
      const isError = lynk.timedOut || lynk.code !== 0;
      return {
        content:
          out ||
          (isError
            ? `lynk affected failed (exit ${lynk.code ?? "unknown"}).`
            : "No links point at the changed lines."),
        isError,
      };
    },
  };
}

/**
 * Return the lynk tools when a `lynk` binary is available. The affected
 * tool is only registered inside a jj or git repository, using whichever
 * the VCS tools use.
 */
export function getLynkTools(): CliToolDef[] {
  if (!commandOk("lynk", ["--help"], 1_000)) return [];
  const tools: CliToolDef[] = [
    lynkLint,
    lynkResolve,
    lynkBacklinks,
    lynkContext,
  ];
  if (inJjRepo()) {
    tools.push(makeAffectedTool("jj", jjAffectedParams, jjDiffArgs));
  } else if (inGitRepo()) {
    tools.push(makeAffectedTool("git", gitAffectedParams, gitDiffArgs));
  }
  return tools;
}
