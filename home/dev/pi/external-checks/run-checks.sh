#!/usr/bin/env bash
# Shared check driver for externally-sourced pi extensions, invoked from the
# pi-extension-check setup hook (setup-hook.sh) during checkPhase.
#
# Verifies the package under <srcRoot> against the exact pi build it will run
# under (<piRoot>, the flake-pinned pi-coding-agent's pi-monorepo):
#   1. peerDependency version compatibility (check-peer-version.cjs), and
#   2. that the extension's TypeScript still typechecks against pi's types.
#
# pi loads extensions via jiti with no type checking, so the tsc pass is the
# only thing catching API drift on pi upgrades. Everything runs on a scratch
# copy under $TMPDIR: the extension's own dependencies (<srcRoot>/node_modules,
# the node_modules npm ci materialized in the build dir) and the pi module tree
# are symlinked in for the run only — nothing is written to the sources or the
# built output, and no cleanup is required (the scratch dir vanishes with the
# build).
#
# usage: run-checks.sh <srcRoot> <piRoot> <includeGlobsJson> <checkPeerScript> <rewriteSubpaths>
set -euo pipefail

srcRoot=$1
piRoot=$2
includeJson=$3
checkPeerScript=$4
rewriteSubpaths=$5

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

cp -r "$srcRoot"/. "$scratch"/
chmod -R u+w "$scratch"
# The npm deps are symlinked in fresh below; drop any copied node_modules
# (the build dir's is a real directory, and copying it is pure waste).
rm -rf "$scratch/node_modules"

cd "$scratch"

# Normalize the package's own `#alias/*` self-imports to relative specifiers
# (subpath resolution is fickle across tsc versions); semantics unchanged.
node "$rewriteSubpaths" "$PWD"

# The extension's own runtime deps (zod, @modelcontextprotocol/*, ...). The pi
# modules are never installed as deps (these packages build with
# --legacy-peer-deps), so the @earendil-works/@types dirs we create below
# cannot clobber anything real.
mkdir -p node_modules/@earendil-works node_modules/@types
if [ -d "$srcRoot/node_modules" ]; then
  for e in "$srcRoot/node_modules"/*; do
    name=$(basename "$e")
    [ "$name" = "@earendil-works" ] && continue
    [ "$name" = "@types" ] && continue
    ln -s "$e" "node_modules/$name"
  done
fi

# The pi module tree (the exact build pi will load), resolved from the real
# store locations so transitive type imports work out of the box.
rm -f node_modules/@earendil-works/pi-coding-agent
ln -s "$piRoot" node_modules/@earendil-works/pi-coding-agent
rm -f node_modules/@earendil-works/pi-tui
ln -s "$piRoot/node_modules/@earendil-works/pi-tui" node_modules/@earendil-works/pi-tui
rm -f node_modules/@earendil-works/pi-ai
ln -s "$piRoot/node_modules/@earendil-works/pi-ai" node_modules/@earendil-works/pi-ai
rm -f node_modules/typebox
ln -s "$piRoot/node_modules/typebox" node_modules/typebox
if [ ! -e node_modules/@types/node ]; then
  ln -s "$piRoot/node_modules/@types/node" node_modules/@types/node
fi

node "$checkPeerScript" "$PWD" "$piRoot"

# Include globs are relative to this tsconfig's directory (= the scratch copy
# root). Base flags mirror upstream extensions' own tsconfigs; moduleResolution
# bundler also handles package.json exports/imports at runtime.
printf '%s\n' \
  '{' \
  '  "compilerOptions": {' \
  '    "target": "ES2024",' \
  '    "lib": ["ESNext"],' \
  '    "module": "ESNext",' \
  '    "moduleResolution": "bundler",' \
  '    "types": ["node"],' \
  '    "strict": true,' \
  '    "noEmit": true,' \
  '    "skipLibCheck": true,' \
  '    "esModuleInterop": true,' \
  '    "allowSyntheticDefaultImports": true,' \
  '    "resolveJsonModule": true,' \
  '    "forceConsistentCasingInFileNames": true,' \
  '    "allowImportingTsExtensions": true' \
  '  },' \
  "  \"include\": ${includeJson}," \
  '  "exclude": ["node_modules"]' \
  '}' \
  >tsconfig.check.json

tsc -p tsconfig.check.json --pretty false
