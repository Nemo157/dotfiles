{ lib
, stdenv
, runCommand
, jq
, buildNpmPackage
, fetchFromGitHub
, autoPatchelfHook
, zlib
, libsecret
}:

# Pi MCP adapter extension (https://github.com/nicobailon/pi-mcp-adapter).
# Exposes MCP servers to Pi through a single lazy proxy tool instead of
# dumping every server's tool definitions into the context window.
#
# Built straight from the tagged GitHub source because the published npm
# tarball ships without a lock file, whereas the repo carries a full
# `package-lock.json` we can feed to buildNpmPackage for a pinned closure.
# Pi loads `index.ts` directly via jiti, so nothing is compiled here;
# buildNpmPackage only materializes `node_modules`.
#
# The upstream lock is a full dev lock: its `@earendil-works/pi-coding-agent`
# devDependency has `hasShrinkwrap: true`, dragging in a large bundled subtree
# whose entries lack `integrity` and make `prefetch-npm-deps` panic. None of
# that is needed at runtime (pi provides the @earendil-works/pi-* peers), so we
# strip devDependencies from both package.json and package-lock.json before
# they ever reach the npm-deps fetcher. The fetcher has no jq of its own, hence
# the pre-clean happens here in a separate runCommand rather than in postPatch.
#
# Regenerating after bumping `version`/`rev`:
#   1. Update `rev` to the new `v<version>` tag commit.
#   2. Set `hash`/`npmDepsHash` to lib.fakeHash, run `colmena build` once,
#      and paste the two hashes nix reports back in below.
#
# Two dependencies ship prebuilt native binaries (`@napi-rs/keyring` for the
# OS credential store used by OAuth, and `recheck`'s ReDoS checker). On Linux
# autoPatchelfHook fixes their interpreter/RPATH; on Darwin the Mach-O
# prebuilds are already relocatable.

let
  rawSrc = fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-mcp-adapter";
    rev = "v2.15.0";
    hash = "sha256-X9EfaPjUVpH85SLjEFbaApqlgtMIdm1yyn9/lui8NKc=";
  };

  # Production-only source: drop dev entries from the manifest and lock so the
  # closure is limited to runtime deps (all of which carry integrity).
  prodSrc = runCommand "pi-mcp-adapter-src-2.15.0" { nativeBuildInputs = [ jq ]; } ''
    cp -r ${rawSrc} $out
    chmod -R +w $out
    jq 'del(.devDependencies)' ${rawSrc}/package.json > $out/package.json
    jq '.packages |= with_entries(select(.value.dev != true))
        | del(.packages."".devDependencies)' \
      ${rawSrc}/package-lock.json > $out/package-lock.json
  '';
in
buildNpmPackage (finalAttrs: {
  pname = "pi-mcp-adapter";
  version = "2.15.0";

  src = prodSrc;

  npmDepsHash = "sha256-81MCukPo9ZMulBqOjVXVuUWQDbpOitihzRgbiYrM3Vc=";

  # Native optional deps carry their own prebuilt binaries; skip install
  # scripts (no node-gyp rebuilds), omit devDependencies (vitest/tsx/etc.,
  # not needed since pi runs index.ts directly), and stop npm from trying to
  # install the @earendil-works/pi-* peer deps that the host pi provides.
  npmFlags = [ "--ignore-scripts" "--omit=dev" "--legacy-peer-deps" ];

  # Nothing to compile: pi loads index.ts directly.
  dontNpmBuild = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    zlib
    libsecret
  ];

  # The unused cross-platform prebuilds pulled in transitively reference libs
  # we don't provide; don't fail the build over binaries we never load.
  autoPatchelfIgnoreMissingDeps = true;

  # Expose the package root (directory containing package.json) so consumers
  # can add it to `settings.packages` without hard-coding the store path.
  passthru.packageRoot =
    "${finalAttrs.finalPackage}/lib/node_modules/pi-mcp-adapter";

  meta = {
    description = "MCP adapter extension for the Pi coding agent";
    homepage = "https://github.com/nicobailon/pi-mcp-adapter";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
