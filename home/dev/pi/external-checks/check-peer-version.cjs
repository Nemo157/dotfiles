// Validates that the pinned pi build (the exact nix package the extension
// will run under) satisfies every @earendil-works/* peerDependency range the
// extension declares. Uses the semver implementation pi itself ships so range
// semantics (^, ~, ||, prerelease exclusion) cannot drift from npm's.
//
// usage: node check-peer-version.cjs <pkgRoot> <piRoot>
//   pkgRoot - dir containing the extension's package.json (the checked tree)
//   piRoot  - the pi-coding-agent package's lib/node_modules/pi-monorepo dir
const { existsSync, readFileSync } = require("node:fs");
const { createRequire } = require("node:module");
const path = require("node:path");

const [, , pkgRoot, piRoot] = process.argv;
const requireFrom = createRequire(path.join(pkgRoot, "package.json"));
const semver = requireFrom(path.join(piRoot, "node_modules", "semver"));

const pkg = JSON.parse(readFileSync(path.join(pkgRoot, "package.json"), "utf8"));
const peers = pkg.peerDependencies ?? {};

let failed = false;
for (const [name, range] of Object.entries(peers)) {
  if (!name.startsWith("@earendil-works/")) continue;

  // pi-coding-agent's own package.json lives at piRoot; the other pi modules
  // (pi-tui, pi-ai) hang off pi's node_modules.
  const versionPath =
    name === "@earendil-works/pi-coding-agent"
      ? path.join(piRoot, "package.json")
      : path.join(piRoot, "node_modules", name, "package.json");

  if (!existsSync(versionPath)) {
    console.log(
      `skip  ${pkg.name}: peer ${name} — not present in this pi bundle; ` +
        `leaving it to the typecheck (${versionPath})`
    );
    continue;
  }

  const installed = JSON.parse(readFileSync(versionPath, "utf8")).version;
  if (semver.satisfies(installed, range)) {
    console.log(`ok    ${pkg.name}: ${name}@${installed} satisfies ${range}`);
  } else {
    console.error(
      `FAIL  ${pkg.name}: ${name}@${installed} does not satisfy peerDependency ${range}`
    );
    failed = true;
  }
}

if (failed) {
  console.error(
    `\nThe ${pkg.name} extension is incompatible with the pi build pinned in\n` +
      `flake.nix (${piRoot}). Either bump ./extensions/${pkg.name}/default.nix\n` +
      "to a release whose peerDependencies cover the installed pi, or pin an\n" +
      "older pi in the flake overlay."
  );
  process.exit(1);
}
