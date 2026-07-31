import { Type } from "typebox";
import {
  runCommand,
  type CustomCliToolDef,
  type CustomRunContext,
} from "./shared";

// gh-pr-comments ---------------------------------------------------------
//
// Review view for the current changes: PR metadata, submitted reviews
// (approve / request-changes / comment bodies), the conversation timeline
// (issue comments), and the inline code-review comments grouped by file with
// their diff context and threaded replies. Roughly `gh pr view --comments`
// plus the inline review comments that command omits.
//
// Everything is done through `gh api` (read-only) and formatted here, so no
// jq/shell pipeline is needed. Crucially this does NOT rely on `gh`'s own
// branch detection, which fails under jj: we resolve the PR by walking git
// HEAD's ancestry and asking GitHub which PR contains each commit.

const TIMEOUT_MS = 30_000;

interface GhContext extends CustomRunContext {}

/** Run `gh` and return trimmed stdout, throwing on failure. */
async function gh(args: string[], ctx: GhContext): Promise<string> {
  const r = await runCommand("gh", args, {
    cwd: ctx.cwd,
    signal: ctx.signal,
    timeoutMs: TIMEOUT_MS,
  });
  if (r.code !== 0) {
    const detail = (r.stderr.trim() || r.stdout.trim() || "no output").trim();
    throw new Error(`gh ${args.join(" ")} failed: ${detail}`);
  }
  return r.stdout;
}

/** Run a `gh api` call and JSON-parse the (possibly paginated) response. */
async function ghApi<T>(endpoint: string, ctx: GhContext, paginate = false): Promise<T> {
  const args = ["api"];
  if (paginate) args.push("--paginate");
  args.push(endpoint);
  const out = await gh(args, ctx);
  return JSON.parse(out || "null") as T;
}

interface Pull {
  number: number;
  state: string;
}

/**
 * Resolve the PR for the current changes without relying on `gh`'s branch
 * detection (which cannot work under jj). We read git HEAD's ancestry — jj
 * keeps a colocated git HEAD at the working-copy parent, so this works for
 * both plain-git and jj checkouts — and ask GitHub which PR each commit
 * belongs to, newest first. Unpushed local commits 404 and are skipped.
 */
async function detectPr(ctx: GhContext): Promise<number> {
  const log = await runCommand("git", ["log", "--format=%H", "-n", "25"], {
    cwd: ctx.cwd,
    signal: ctx.signal,
    timeoutMs: TIMEOUT_MS,
  });
  if (log.code !== 0) {
    throw new Error(
      `could not read git history to locate the PR: ${log.stderr.trim()}`,
    );
  }
  const shas = log.stdout
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);
  for (const sha of shas) {
    let pulls: Pull[];
    try {
      pulls = await ghApi<Pull[]>(`repos/{owner}/{repo}/commits/${sha}/pulls`, ctx);
    } catch {
      // Commit not on GitHub (unpushed) or transient error — try the next.
      continue;
    }
    if (Array.isArray(pulls) && pulls.length > 0) {
      const open = pulls.find((p) => p.state === "open") ?? pulls[0];
      return open.number;
    }
  }
  throw new Error(
    "could not find a PR for the current changes. Push the branch first, or " +
      "pass the `pr` parameter explicitly.",
  );
}

// --- formatting helpers ---------------------------------------------------

function blockquote(body: string, indent = ""): string {
  const text = (body ?? "").replace(/\r\n/g, "\n").replace(/\s+$/, "");
  if (text.length === 0) return `${indent}> _(no comment body)_`;
  return text
    .split("\n")
    .map((l) => `${indent}>${l.length ? " " + l : ""}`)
    .join("\n");
}

function reviewStateLabel(state: string): string {
  switch (state) {
    case "APPROVED":
      return "approved";
    case "CHANGES_REQUESTED":
      return "requested changes";
    case "COMMENTED":
      return "commented";
    case "DISMISSED":
      return "dismissed";
    case "PENDING":
      return "pending review";
    default:
      return state.toLowerCase();
  }
}

interface PrMeta {
  number: number;
  title: string;
  state: string;
  draft?: boolean;
  html_url: string;
  user: { login: string } | null;
  head: { ref: string };
  base: { ref: string };
}

interface Review {
  user: { login: string } | null;
  body: string;
  state: string;
  submitted_at: string | null;
}

interface IssueComment {
  user: { login: string } | null;
  body: string;
  created_at: string;
}

interface ReviewComment {
  id: number;
  path: string;
  user: { login: string } | null;
  body: string;
  diff_hunk: string | null;
  in_reply_to_id: number | null;
  line: number | null;
  original_line: number | null;
}

function login(u: { login: string } | null): string {
  return u?.login ?? "unknown";
}

async function buildReport(pr: number, ctx: GhContext): Promise<string> {
  const [meta, reviews, issueComments, inline] = await Promise.all([
    ghApi<PrMeta>(`repos/{owner}/{repo}/pulls/${pr}`, ctx),
    ghApi<Review[]>(`repos/{owner}/{repo}/pulls/${pr}/reviews`, ctx, true),
    ghApi<IssueComment[]>(`repos/{owner}/{repo}/issues/${pr}/comments`, ctx, true),
    ghApi<ReviewComment[]>(`repos/{owner}/{repo}/pulls/${pr}/comments`, ctx, true),
  ]);

  const out: string[] = [];

  // Header.
  const stateBits = [meta.draft ? "draft" : meta.state.toLowerCase()];
  out.push(`# PR #${meta.number}: ${meta.title}`);
  out.push(
    `${stateBits.join(" ")} · @${login(meta.user)} · ` +
      `\`${meta.head.ref}\` → \`${meta.base.ref}\``,
  );
  out.push(meta.html_url);

  // Submitted reviews. Skip empty COMMENTED shells (their inline comments are
  // rendered below); keep approvals / change-requests even when body-less.
  const meaningful = (reviews ?? []).filter(
    (r) => (r.body ?? "").trim().length > 0 || r.state !== "COMMENTED",
  );
  if (meaningful.length > 0) {
    out.push("\n## Reviews");
    for (const r of meaningful) {
      out.push(`\n**@${login(r.user)}** ${reviewStateLabel(r.state)}:`);
      if ((r.body ?? "").trim().length > 0) out.push(blockquote(r.body));
    }
  }

  // Conversation timeline (issue comments).
  if ((issueComments ?? []).length > 0) {
    out.push("\n## Conversation");
    for (const c of issueComments) {
      out.push(`\n**@${login(c.user)}** commented:`);
      out.push(blockquote(c.body));
    }
  }

  // Inline review comments, grouped by file, threaded by in_reply_to_id.
  const roots = (inline ?? []).filter((c) => c.in_reply_to_id == null);
  const repliesByRoot = new Map<number, ReviewComment[]>();
  for (const c of inline ?? []) {
    if (c.in_reply_to_id == null) continue;
    const list = repliesByRoot.get(c.in_reply_to_id) ?? [];
    list.push(c);
    repliesByRoot.set(c.in_reply_to_id, list);
  }

  if (roots.length > 0) {
    out.push("\n## Inline comments");
    // Preserve API order but group consecutive comments per file under one
    // heading.
    const byFile = new Map<string, ReviewComment[]>();
    for (const c of roots) {
      const list = byFile.get(c.path) ?? [];
      list.push(c);
      byFile.set(c.path, list);
    }
    for (const [path, comments] of byFile) {
      out.push(`\n### ${path}`);
      for (const c of comments) {
        if (c.diff_hunk && c.diff_hunk.trim().length > 0) {
          out.push("```diff\n" + c.diff_hunk.replace(/\s+$/, "") + "\n```");
        }
        out.push(`**@${login(c.user)}** commented:`);
        out.push(blockquote(c.body));
        const replies = repliesByRoot.get(c.id) ?? [];
        for (const rep of replies) {
          out.push(`  ↳ **@${login(rep.user)}** replied:`);
          out.push(blockquote(rep.body, "  "));
        }
        out.push("---");
      }
    }
  }

  if (
    meaningful.length === 0 &&
    (issueComments ?? []).length === 0 &&
    roots.length === 0
  ) {
    out.push("\n_No reviews or comments yet._");
  }

  return out.join("\n");
}

const params = Type.Object({
  pr: Type.Optional(
    Type.Integer({
      minimum: 1,
      description:
        "PR number to show. When omitted, the PR for the current changes is " +
        "used.",
    }),
  ),
});

const ghPrComments: CustomCliToolDef<typeof params> = {
  name: "gh-pr-comments",
  label: "gh pr comments",
  command: "gh",
  description:
    "Show the GitHub PR review for the current changes: PR metadata, " +
    "submitted reviews (approvals / change requests / comment bodies), the " +
    "conversation timeline, and the inline code-review comments grouped by " +
    "file with diff context and threaded replies. Like `gh pr view " +
    "--comments` but also includes inline review comments. Pass `pr` to " +
    "target a specific PR number.",
  parameters: params,
  displayArgs(p) {
    return p.pr !== undefined
      ? ["pr", "comments", String(p.pr)]
      : ["pr", "comments"];
  },
  async run(p, ctx) {
    const pr = p.pr ?? (await detectPr(ctx));
    return { content: await buildReport(pr, ctx) };
  },
};

export const ghTools = [ghPrComments];
