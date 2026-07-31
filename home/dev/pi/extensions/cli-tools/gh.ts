import { Type } from "typebox";
import {
  buildDefaultSpec,
  runCommand,
  type CliToolDetails,
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

/** Run a `gh api graphql` query with string/number variables and parse it. */
async function ghGraphql<T>(
  query: string,
  vars: { strings?: Record<string, string>; ints?: Record<string, number> },
  ctx: GhContext,
): Promise<T> {
  const args = ["api", "graphql", "-f", `query=${query}`];
  for (const [k, v] of Object.entries(vars.strings ?? {})) {
    args.push("-f", `${k}=${v}`);
  }
  for (const [k, v] of Object.entries(vars.ints ?? {})) {
    args.push("-F", `${k}=${v}`);
  }
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
  base: { ref: string; repo: { name: string; owner: { login: string } } };
}

// GraphQL timeline nodes used to reconstruct branch push activity.
interface ForcePushNode {
  __typename: "HeadRefForcePushedEvent";
  actor: { login: string } | null;
  createdAt: string;
  beforeCommit: { abbreviatedOid: string } | null;
  afterCommit: { abbreviatedOid: string } | null;
}
interface CommitNode {
  __typename: "PullRequestCommit";
  commit: {
    abbreviatedOid: string;
    committedDate: string;
    author: { user: { login: string } | null; name: string | null } | null;
  };
}
type TimelineNode = ForcePushNode | CommitNode | { __typename: string };

interface TimelineResponse {
  data?: {
    repository?: {
      pullRequest?: { timelineItems?: { nodes?: TimelineNode[] } } | null;
    } | null;
  };
}

const TIMELINE_QUERY = `query($owner:String!,$name:String!,$number:Int!){
  repository(owner:$owner,name:$name){
    pullRequest(number:$number){
      timelineItems(first:250,itemTypes:[PULL_REQUEST_COMMIT,HEAD_REF_FORCE_PUSHED_EVENT]){
        nodes{
          __typename
          ... on HeadRefForcePushedEvent{
            actor{login}
            createdAt
            beforeCommit{abbreviatedOid}
            afterCommit{abbreviatedOid}
          }
          ... on PullRequestCommit{
            commit{
              abbreviatedOid
              committedDate
              author{user{login} name}
            }
          }
        }
      }
    }
  }
}`;

function fmtDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  const p = (n: number) => String(n).padStart(2, "0");
  return (
    `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())} ` +
    `${p(d.getUTCHours())}:${p(d.getUTCMinutes())}Z`
  );
}

function actorDisplay(loginName?: string | null, name?: string | null): string {
  if (loginName) return `@${loginName}`;
  return name ?? "someone";
}

/**
 * Reconstruct branch push activity from the GraphQL timeline. Consecutive
 * `PullRequestCommit` nodes are collapsed into a single "pushed N commits"
 * entry (GitHub doesn't expose push grouping directly, so adjacency is the
 * best available heuristic); force-push events are rendered with their
 * before/after commits like the web UI.
 */
function buildActivity(nodes: TimelineNode[]): string[] {
  const lines: string[] = [];
  let run: CommitNode[] = [];
  const flush = () => {
    if (run.length === 0) return;
    const last = run[run.length - 1];
    const n = run.length;
    const who = actorDisplay(
      last.commit.author?.user?.login,
      last.commit.author?.name,
    );
    lines.push(
      `- ${who} pushed ${n} commit${n === 1 ? "" : "s"} → ` +
        `\`${last.commit.abbreviatedOid}\` (${fmtDate(last.commit.committedDate)})`,
    );
    run = [];
  };
  for (const node of nodes) {
    if (node.__typename === "PullRequestCommit") {
      run.push(node as CommitNode);
    } else if (node.__typename === "HeadRefForcePushedEvent") {
      flush();
      const fp = node as ForcePushNode;
      const before = fp.beforeCommit?.abbreviatedOid ?? "?";
      const after = fp.afterCommit?.abbreviatedOid ?? "?";
      lines.push(
        `- ${actorDisplay(fp.actor?.login)} force-pushed ` +
          `\`${before}\` → \`${after}\` (${fmtDate(fp.createdAt)})`,
      );
    }
  }
  flush();
  return lines;
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

interface ReviewDecision {
  reviewDecision: string | null;
}

interface Report {
  text: string;
  reviewDecision: string;
  commentCount: number;
}

async function buildReport(pr: number, ctx: GhContext): Promise<Report> {
  const meta = await ghApi<PrMeta>(`repos/{owner}/{repo}/pulls/${pr}`, ctx);
  const [decision, reviews, issueComments, inline, activity] = await Promise.all([
    gh(["pr", "view", String(pr), "--json", "reviewDecision"], ctx)
      .then((o) => (JSON.parse(o || "{}") as ReviewDecision).reviewDecision ?? "")
      .catch(() => ""),
    ghApi<Review[]>(`repos/{owner}/{repo}/pulls/${pr}/reviews`, ctx, true),
    ghApi<IssueComment[]>(`repos/{owner}/{repo}/issues/${pr}/comments`, ctx, true),
    ghApi<ReviewComment[]>(`repos/{owner}/{repo}/pulls/${pr}/comments`, ctx, true),
    ghGraphql<TimelineResponse>(
      TIMELINE_QUERY,
      {
        strings: { owner: meta.base.repo.owner.login, name: meta.base.repo.name },
        ints: { number: pr },
      },
      ctx,
    )
      .then((r) =>
        buildActivity(r.data?.repository?.pullRequest?.timelineItems?.nodes ?? []),
      )
      .catch(() => [] as string[]),
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

  // Branch activity: pushes and force-pushes, like the web UI timeline.
  if (activity.length > 0) {
    out.push("\n## Branch activity");
    out.push(activity.join("\n"));
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
    roots.length === 0 &&
    activity.length === 0
  ) {
    out.push("\n_No reviews or comments yet._");
  }

  return {
    text: out.join("\n"),
    reviewDecision: decision,
    commentCount: (issueComments ?? []).length + (inline ?? []).length,
  };
}

/** Human label for GitHub's `reviewDecision`; empty string when none. */
function reviewDecisionLabel(decision: string): string {
  switch (decision) {
    case "APPROVED":
      return "approved";
    case "CHANGES_REQUESTED":
      return "changes requested";
    case "REVIEW_REQUIRED":
      return "review required";
    default:
      return "";
  }
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
    const report = await buildReport(pr, ctx);
    return {
      content: report.text,
      details: {
        reviewDecision: report.reviewDecision,
        commentCount: report.commentCount,
      },
    };
  },
  renderResult(result, opts, theme, ctx) {
    const spec = buildDefaultSpec(result, opts, theme, ctx);
    const details = result.details as
      | (CliToolDetails & { reviewDecision?: string; commentCount?: number })
      | undefined;
    if (details?.commentCount !== undefined) {
      const parts: string[] = [];
      const label = reviewDecisionLabel(details.reviewDecision ?? "");
      if (label) {
        const color =
          details.reviewDecision === "CHANGES_REQUESTED"
            ? "error"
            : details.reviewDecision === "APPROVED"
              ? "success"
              : "warning";
        parts.push(theme.fg(color, label));
      }
      const n = details.commentCount;
      parts.push(theme.fg("dim", `${n} comment${n === 1 ? "" : "s"}`));
      spec.summary = parts.join(theme.fg("dim", " · "));
    }
    return spec;
  },
};

export const ghTools = [ghPrComments];
