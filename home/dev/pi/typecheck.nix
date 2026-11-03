{
  lib,
  runCommand,
  callPackage,
  typescript,
  pi-coding-agent,
}:

# Typechecks the local pi extensions (home/dev/pi/extensions/*/*.ts) against
# the exact pi build they run under, and outputs the checked source tree.
# Pi loads extensions via jiti with no type checking, so this is the only
# thing catching API drift on pi upgrades. home/dev/pi/default.nix loads
# extensions from this output (`${checked}/<name>/index.ts`), so a type error
# fails the system build rather than shipping.
#
# There is no npm install here: a node_modules tree is assembled from
# symlinks into the pi package (its own entry point plus the deps it
# re-exposes to extensions: pi-tui, pi-ai, typebox, @types/node) and into
# the web-fetch extension's pinned runtime deps. tsc resolves symlinks to
# their real paths, so transitive type imports resolve from the pi package's
# own node_modules. The web-fetch package itself is still built from its own
# source (its node_modules are needed here, so it can't consume this output).

let
  piRoot = "${pi-coding-agent}/lib/node_modules/pi-monorepo";
  piModules = "${piRoot}/node_modules";
  webFetchModules = "${(callPackage ./extensions/web-fetch { }).packageRoot}/node_modules";
in
runCommand "pi-extensions"
  {
    src = lib.cleanSource ./extensions;
    nativeBuildInputs = [ typescript ];
  }
  ''
    cp -r "$src" extensions
    chmod -R u+w extensions
    cd extensions

    mkdir -p node_modules/@earendil-works node_modules/@types node_modules/@mozilla
    ln -s ${piRoot} node_modules/@earendil-works/pi-coding-agent
    ln -s ${piModules}/@earendil-works/pi-tui node_modules/@earendil-works/pi-tui
    ln -s ${piModules}/@earendil-works/pi-ai node_modules/@earendil-works/pi-ai
    ln -s ${piModules}/typebox node_modules/typebox
    ln -s ${piModules}/@types/node node_modules/@types/node
    ln -s ${webFetchModules}/@mozilla/readability node_modules/@mozilla/readability
    ln -s ${webFetchModules}/linkedom node_modules/linkedom

    tsc --version
    tsc -p tsconfig.json --pretty false

    cp -r "$src" $out
  ''
