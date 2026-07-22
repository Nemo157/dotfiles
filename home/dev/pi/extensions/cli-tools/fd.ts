import { Type } from "typebox";
import { expandTilde, type StructuredCliToolDef } from "./shared";

const fdParams = Type.Object({
  pattern: Type.Optional(
    Type.String({
      description:
        "Regex to match filenames against. Omit to list everything under path.",
    }),
  ),
  path: Type.Optional(
    Type.String({
      description:
        "Root to search. Defaults to cwd. Passed after `--` so it is " +
        "never parsed as a flag.",
    }),
  ),
  glob: Type.Optional(
    Type.Boolean({
      description: "Interpret `pattern` as a glob rather than a regex (-g).",
    }),
  ),
  type: Type.Optional(
    Type.Union(
      [
        Type.Literal("f"),
        Type.Literal("d"),
        Type.Literal("l"),
        Type.Literal("x"),
        Type.Literal("e"),
        Type.Literal("s"),
      ],
      {
        description:
          "Restrict result type: f=file, d=directory, l=symlink, x=executable, e=empty, s=socket.",
      },
    ),
  ),
  extension: Type.Optional(
    Type.Array(Type.String(), {
      description: "Restrict to given file extensions (-e), without leading dot.",
    }),
  ),
  hidden: Type.Optional(
    Type.Boolean({ description: "Include hidden files/dirs (--hidden)." }),
  ),
  noIgnore: Type.Optional(
    Type.Boolean({
      description: "Do not respect .gitignore/.ignore (--no-ignore).",
    }),
  ),
  caseSensitive: Type.Optional(
    Type.Boolean({ description: "Force case-sensitive matching (-s)." }),
  ),
  fullPath: Type.Optional(
    Type.Boolean({
      description: "Match pattern against the full path, not just filename (-p).",
    }),
  ),
  maxDepth: Type.Optional(
    Type.Integer({
      minimum: 1,
      maximum: 64,
      description: "Limit directory descent depth (--max-depth).",
    }),
  ),
});

export const fdTool: StructuredCliToolDef<typeof fdParams> = {
  name: "fd",
  label: "fd (find)",
  command: "fd",
  description:
    "Find files/directories by name using fd. Provide optional `pattern` " +
    "and typed flags. Respects .gitignore by default. Read-only.",
  promptSnippet:
    "Use fd to find files by name/pattern; prefer it over ad-hoc find.",
  promptGuidelines: [
    "Use fd to locate files or directories. Set glob=true for shell-style patterns.",
  ],
  parameters: fdParams,
  buildArgs(p) {
    const args: string[] = [];
    if (p.glob) args.push("-g");
    if (p.hidden) args.push("--hidden");
    if (p.noIgnore) args.push("--no-ignore");
    if (p.caseSensitive) args.push("-s");
    if (p.fullPath) args.push("-p");
    if (p.type) args.push("-t", p.type);
    for (const ext of p.extension ?? []) args.push("-e", ext);
    if (p.maxDepth !== undefined) args.push("--max-depth", String(p.maxDepth));
    // Pattern is positional; use empty string if omitted so `--` still
    // delimits the paths that follow. fd treats an empty pattern as "match
    // everything".
    args.push(p.pattern ?? "");
    args.push("--");
    if (p.path !== undefined) args.push(expandTilde(p.path));
    return args;
  },
};
