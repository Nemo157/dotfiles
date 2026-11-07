// Rewrites a pi extension's own `#alias/*` / `#alias` self-imports (declared
// in its package.json `imports` map) into specifiers relative to each
// importing file, so tsc resolves them regardless of its (version-fickle)
// subpath-import support. This runs only on the disposable scratch copy, never
// on the shipped sources, and only changes the specifier spelling — module
// semantics are identical.
//
// usage: node rewrite-subpaths.cjs <srcRoot>
const { readFileSync, writeFileSync, readdirSync, statSync, existsSync } = require("node:fs");
const path = require("node:path");

const root = process.argv[2];
const pkg = JSON.parse(readFileSync(path.join(root, "package.json"), "utf8"));
const imports = pkg.imports ?? {};

// rules: { kind: "pattern", token: "#src/", targetDir: "src" } // package-root target dir
//        { kind: "exact",  token: "#src",   targetFile: "src/x" }
const rules = [];
for (const [key, raw] of Object.entries(imports)) {
  if (!key.startsWith("#")) continue;
  let target = Array.isArray(raw) ? raw[0] : raw;
  if (typeof target !== "string") continue;
  if (key.endsWith("/*") && target.endsWith("/*")) {
    // "#src/*" -> "./src/*": strip only the `*` so targetDir keeps its trailing `/`.
    rules.push({ kind: "pattern", token: key.slice(0, -1), targetDir: target.slice(0, -1) });
  } else {
    // "#foo" -> "./path/to/file"
    rules.push({ kind: "exact", token: key, targetFile: target.replace(/^\.\//, "") });
  }
}
if (rules.length === 0) process.exit(0);

function* tsFiles(dir, rel = "") {
  for (const entry of readdirSync(dir)) {
    if (entry === "node_modules" || entry === "tsconfig.check.json") continue;
    const p = path.join(dir, entry);
    const r = rel ? `${rel}/${entry}` : entry;
    if (statSync(p).isDirectory()) yield* tsFiles(p, r);
    else if (entry.endsWith(".ts")) yield { p, r };
  }
}

// Ensure a relative specifier starts with ./ or ../ so it is not mistaken for
// a bare (package) module name.
const asRelative = (sp) => (sp.startsWith("./") || sp.startsWith("../") ? sp : "./" + sp);

const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

for (const { p, r } of tsFiles(root)) {
  const fileDir = path.dirname(r); // e.g. "src/path" ("" at root)
  const fromDir = (target) => {
    const rel = path.relative(fileDir, target).split("\\").join("/");
    return asRelative(rel);
  };
  // Resolve an extensionless module path (package-relative) the way node/TS
  // does, so `#src/service` maps to the FILE `src/service.ts` rather than the
  // sibling directory `src/service/`. Without this a self-import from inside
  // that directory rewrites to `./`, which points at the no-index directory.
  const resolveTarget = (rel) => {
    for (const cand of [rel + ".ts", rel + "/index.ts", rel]) {
      if (existsSync(path.join(root, cand))) return cand;
    }
    return rel;
  };

  const s0 = readFileSync(p, "utf8");

  const patternRe = (token, targetDir) =>
    new RegExp(`(["'])(?:${escapeRe(token)})([^"']*?)\\1`, "g");
  const exactRe = (token, targetFile) =>
    new RegExp(`(["'])${escapeRe(token)}(["'])`, "g");

  let s = s0;
  for (const rule of rules) {
    if (rule.kind === "pattern") {
      s = s.replace(patternRe(rule.token, rule.targetDir), (m, q, rest) =>
        q + fromDir(resolveTarget(`${rule.targetDir}${rest}`)) + q
      );
    } else {
      s = s.replace(exactRe(rule.token, rule.targetFile), (m, q) =>
        q + fromDir(resolveTarget(rule.targetFile)) + q
      );
    }
  }

  if (s !== s0) writeFileSync(p, s, "utf8");
}