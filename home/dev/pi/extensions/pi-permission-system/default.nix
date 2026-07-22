{ lib, buildNpmPackage, fetchurl, jq }:

# Pi extension packaged from npm. The npm tarball ships without a lock file,
# so we keep our own `package-lock.json` next to this derivation (generated
# with `npm install --package-lock-only --omit=dev --ignore-scripts`, then
# stripped of dev entries via jq) and feed it to buildNpmPackage. That gives
# us a fully pinned dependency closure.
#
# Runtime deps: tree-sitter-bash, web-tree-sitter, zod (plus two transitive
# packages pulled in by tree-sitter-bash). The extension only ever loads the
# WASM parser (see src/access-intent/bash/parser.ts in the upstream tarball),
# so we drop the native `prebuilds/` directory to keep the output
# architecture-independent and avoid dragging patchelf into the picture.

buildNpmPackage (finalAttrs: {
  pname = "pi-permission-system";
  version = "20.10.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@gotgenes/pi-permission-system/-/pi-permission-system-${finalAttrs.version}.tgz";
    hash = "sha512-7jWdwzfwIYper9jeYkb3f74mPGZp/hYvzHYHgf6WFoSnAPq3nr4a/NeuBSCKax3Kv0r8EwScxNWQ5y25JcOJQg==";
  };

  nativeBuildInputs = [ jq ];

  # Drop devDependencies from package.json in lockstep with the pruned
  # lock file — otherwise `npm ci` still tries to resolve them against the
  # (empty) offline npm cache even with `--omit=dev`.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    jq 'del(.devDependencies)' package.json > package.json.new
    mv package.json.new package.json
  '';

  npmDepsHash = "sha256-9iiLVTSgEBk9C3WqgzcKB9b/fjQ2Tbuwzel6qbkIfQo=";

  # tree-sitter-bash's install script invokes node-gyp-build to grab a
  # prebuilt native binding we don't use; skip all install scripts to keep
  # the build hermetic. `--omit=dev` matches the pruned lock file so npm ci
  # doesn't try to fetch dev-only packages that aren't in `npmDeps`.
  # `--legacy-peer-deps` stops npm 7+ from auto-installing peer deps
  # (@earendil-works/pi-coding-agent, @earendil-works/pi-tui) which are
  # provided by the host pi installation at runtime.
  npmFlags = [ "--ignore-scripts" "--omit=dev" "--legacy-peer-deps" ];

  # Nothing to compile: pi loads `src/index.ts` directly.
  dontNpmBuild = true;

  postInstall = ''
    rm -rf "$out/lib/node_modules/@gotgenes/pi-permission-system/node_modules/tree-sitter-bash/prebuilds"
  '';

  # Expose a convenient attribute so consumers can reference the package
  # root (the directory containing package.json) without hard-coding the
  # $out/lib/node_modules/... path.
  passthru.packageRoot =
    "${finalAttrs.finalPackage}/lib/node_modules/@gotgenes/pi-permission-system";

  meta = {
    description = "Permission enforcement extension for the Pi coding agent";
    homepage = "https://github.com/gotgenes/pi-permission-system";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
