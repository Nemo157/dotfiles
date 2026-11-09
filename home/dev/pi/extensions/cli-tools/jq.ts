// jq wrapper: read-only JSON querying from a file or inline text.
//
// jq is intrinsically side-effect free — it writes only to stdout and has no
// file/network access — so the permission config treats it like rg/fd. The
// `path` param still feeds the permission system's input.path convention (the
// `path` and `external_directory` gates apply to it), while the `input` param
// pipes inline JSON through stdin, which the shared runner only wires up when
// a tool declares a `stdin` producer (see shared.ts).

import { Type, type Static } from "typebox";
import {
  commandOk,
  expandTilde,
  type CliToolDef,
  type JsonValue,
  type StructuredCliToolDef,
} from "./shared";

const jqParams = Type.Object({
  filter: Type.Optional(
    Type.String({
      description:
        "jq program/expression to run. Omit to pretty-print (default `.`).",
    }),
  ),
  path: Type.Optional(
    Type.String({
      description:
        "JSON file to query. Mutually exclusive with `input` (path wins if both arrive).",
    }),
  ),
  input: Type.Optional(
    Type.String({
      description:
        "Inline JSON text to query instead of a file (piped to jq via stdin). " +
        "Use when the JSON is already in context, e.g. from another tool's output.",
    }),
  ),
  raw: Type.Optional(
    Type.Boolean({
      description:
        "Raw string output (-r): strings emitted unquoted, unescaped.",
    }),
  ),
  compact: Type.Optional(
    Type.Boolean({
      description:
        "Compact output (-c): one JSON value per line instead of pretty-printing.",
    }),
  ),
  slurp: Type.Optional(
    Type.Boolean({
      description:
        "Slurp all inputs into a single array first (-s); useful for JSONL.",
    }),
  ),
  args: Type.Optional(
    Type.Record(Type.String(), Type.String(), {
      description: "Named string args bound as $name in the filter (jq --arg).",
    }),
  ),
});

const jqOutput = Type.Object({
  values: Type.Array(Type.Unknown(), {
    description:
      "Each value jq emitted, parsed. With `raw`, the output lines as strings.",
  }),
});

/**
 * Split jq's output (a newline-separated stream of pretty-printed or compact
 * JSON values) into the raw text of each top-level value. Newlines can only
 * appear between tokens, so a value ends at the first newline at depth 0.
 */
function splitJsonStream(text: string): string[] {
  const out: string[] = [];
  let depth = 0;
  let inString = false;
  let escaped = false;
  let start = 0;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (c === "\\") escaped = true;
      else if (c === '"') inString = false;
    } else if (c === '"') inString = true;
    else if (c === "{" || c === "[") depth++;
    else if (c === "}" || c === "]") depth--;
    else if (c === "\n" && depth === 0) {
      out.push(text.slice(start, i));
      start = i + 1;
    }
  }
  out.push(text.slice(start));
  return out.filter((s) => s.trim().length > 0);
}

function parseJqOutput(stdout: string, raw: boolean): JsonValue {
  const lines = () => stdout.split("\n").filter((l) => l.length > 0);
  if (raw) return { values: lines() };
  try {
    return {
      values: splitJsonStream(stdout).map((s) => JSON.parse(s) as JsonValue),
    };
  } catch {
    // Shouldn't happen for jq's own output; degrade to plain lines.
    return { values: lines() };
  }
}

function buildJqArgs(p: Static<typeof jqParams>): string[] {
  const args: string[] = [];
  if (p.raw) args.push("-r");
  if (p.compact) args.push("-c");
  if (p.slurp) args.push("-s");
  for (const [name, value] of Object.entries(p.args ?? {})) {
    if (typeof value === "string") args.push("--arg", name, value);
  }
  // `--` terminates jq's option parsing (jq 1.7+), so filter and path are
  // always taken positionally even when they start with `-`: jq picks its
  // program as the first positional argument and the rest as input files.
  // Without it a filter like `-c` would silently be parsed as an option.
  args.push("--");
  args.push(p.filter ?? ".");
  if (p.path !== undefined) args.push(expandTilde(p.path));
  return args;
}

export const jqTool: StructuredCliToolDef<typeof jqParams> = {
  name: "jq",
  label: "jq (JSON processor)",
  command: "jq",
  description:
    "Query or transform JSON with jq. Reads a JSON file (`path`) or inline " +
    "JSON text (`input`), applies the jq `filter` expression, and returns the " +
    "result. Read-only: jq never modifies files. Reach for it on lockfiles " +
    "(flake.lock, Cargo.lock, package-lock.json), JSONL, and structured data " +
    "too large to read whole. Omit `filter` to pretty-print. Use `raw` to " +
    "get unquoted strings, `slurp` for JSONL inputs, `args` to bind $variables.",
  parameters: jqParams,
  outputSchema: jqOutput,
  structured(raw) {
    const p = raw.params as Static<typeof jqParams>;
    return parseJqOutput(raw.stdout, p.raw === true);
  },
  buildArgs: buildJqArgs,
  stdin(p) {
    // jq would concatenate stdin inputs with file inputs; when both arrive
    // prefer the explicit file and drop the inline text.
    return p.path !== undefined ? undefined : p.input;
  },
};

/**
 * Return the jq tool when its binary exists; register nothing otherwise.
 */
export function getJqTools(): CliToolDef[] {
  if (!commandOk("jq", ["--version"])) return [];
  return [jqTool];
}
