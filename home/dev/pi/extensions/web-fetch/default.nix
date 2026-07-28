{ lib, buildNpmPackage }:

# Local Pi extension packaged with its npm runtime dependencies
# (@mozilla/readability + linkedom). Pi loads `index.ts` directly via jiti, so
# nothing is compiled here — buildNpmPackage is used purely to materialize a
# pinned `node_modules` next to the sources.
#
# Regenerating after changing dependencies:
#   1. cd home/dev/pi/extensions/web-fetch
#   2. npm install --package-lock-only --omit=dev --legacy-peer-deps
#   3. nix build (or colmena build) once to learn the correct npmDepsHash,
#      then paste it below in place of lib.fakeHash.

buildNpmPackage (finalAttrs: {
  pname = "pi-web-fetch";
  version = "1.0.0";

  src = lib.cleanSource ./.;

  npmDepsHash = "sha256-jyi81pXSgDl9t1yQhkMGC++Qf340XEOsTA1uxrBWbAY=";

  # Peer deps (@earendil-works/pi-*) are provided by the host pi install at
  # runtime; --legacy-peer-deps stops npm from trying to fetch them.
  npmFlags = [ "--omit=dev" "--legacy-peer-deps" ];

  # Nothing to build: pi loads index.ts directly.
  dontNpmBuild = true;

  # Expose the package root (directory containing package.json) so consumers
  # can add it to `settings.packages` without hard-coding the store path.
  passthru.packageRoot =
    "${finalAttrs.finalPackage}/lib/node_modules/web-fetch";

  meta = {
    description = "Web fetch/extract tool for the Pi coding agent";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
