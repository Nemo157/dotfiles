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
# re-exposes to extensions: pi-tui, pi-ai, typebox, @types/node), into
# the web-fetch extension's pinned runtime deps, and into the built
# pi-permission-system package (so extensions can typecheck against its
# real public API via `import type`). tsc resolves symlinks to their real
# paths, so transitive type imports resolve from each package's own
# node_modules. The web-fetch / pi-permission-system packages themselves are
# still built from their own source (their node_modules are needed here, so
# they can't consume this output).

let
  piRoot = "${pi-coding-agent}/lib/node_modules/pi-monorepo";
  piModules = "${piRoot}/node_modules";
  webFetchModules = "${(callPackage ./extensions/web-fetch { }).packageRoot}/node_modules";
  # The real, installed pi-permission-system package. Several local extensions
  # read its service off globalThis (dependency-free at runtime), but bind
  # their types to this package so tsc validates their usage against the actual
  # public API (dist/public.d.ts) rather than a hand-maintained copy — so API
  # drift / signature changes now fail the build instead of silently breaking.
  piPermissionSystemRoot = (callPackage ./extensions/pi-permission-system { }).packageRoot;
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

    mkdir -p node_modules/@earendil-works node_modules/@types node_modules/@mozilla node_modules/@gotgenes
    ln -s ${piRoot} node_modules/@earendil-works/pi-coding-agent
    ln -s ${piPermissionSystemRoot} node_modules/@gotgenes/pi-permission-system
    ln -s ${piModules}/@earendil-works/pi-tui node_modules/@earendil-works/pi-tui
    ln -s ${piModules}/@earendil-works/pi-ai node_modules/@earendil-works/pi-ai
    ln -s ${piModules}/typebox node_modules/typebox
    ln -s ${piModules}/@types/node node_modules/@types/node
    ln -s ${webFetchModules}/@mozilla/readability node_modules/@mozilla/readability
    ln -s ${webFetchModules}/linkedom node_modules/linkedom
    ln -s ${webFetchModules}/unpdf node_modules/unpdf

    tsc --version
    tsc -p tsconfig.json --pretty false

    # Ship the pi-permission-system package for the extensions' *value* imports.
    # pi aliases only @earendil-works/* + typebox for source-tree extensions, so
    # a bare `@gotgenes/...` import would not otherwise resolve at runtime. Node
    # (via jiti) resolves node_modules by walking up from each extension file to
    # this tree root, so this symlink makes those imports work. The store output
    # dir may be read-only until finalised, so assemble in a writable staging
    # dir and move it into place.
    mkdir -p staging
    cp -r "$src"/. staging/
    mkdir -p staging/node_modules/@gotgenes
    ln -s ${piPermissionSystemRoot} staging/node_modules/@gotgenes/pi-permission-system
    cp -a staging/. $out
  ''
