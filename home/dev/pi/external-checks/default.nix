{
  lib,
  makeSetupHook,
  typescript,
  nodejs,
  jq,
  pi-coding-agent,
}:
# Build-time check hook for externally-sourced pi extensions
# (extensions/pi-permission-system, pi-mcp-adapter, pine-of-glass).
#
# Add `piExtensionCheck` to a package's nativeBuildInputs (plus doCheck = true;
# stdenv defaults it to false) and the hook verifies the package in checkPhase
# against the exact pi build it will run under, all derived automatically:
#   - the pi module tree comes from pi-coding-agent (passed here by the overlay,
#     i.e. the same flake-pinned pi that config.programs.pi.package resolves
#     to), so any pi bump re-checks every extension before deploy;
#   - the tsc include globs come from the package's own `pi.extensions` entry
#     directories in package.json;
#   - the extension's runtime deps come from its $PWD/node_modules when present.
#
# The check (see run-checks.sh) is:
#   1. peerDependency version compatibility (check-peer-version.cjs), checked
#      against the versions actually inside the pi package, and
#   2. a tsc run against pi's types — pi loads extensions via jiti with no
#      type checking, so this is the only thing catching API drift on pi
#      upgrades. It runs on a scratch copy, so nothing is written to the
#      sources or the built output.
makeSetupHook {
  name = "pi-extension-check";
  propagatedBuildInputs = [
    typescript
    nodejs
  ];
  substitutions = {
    runChecks = ./run-checks.sh;
    checkPeerVersion = ./check-peer-version.cjs;
    rewriteSubpaths = ./rewrite-subpaths.cjs;
    piRoot = "${pi-coding-agent}/lib/node_modules/pi-monorepo";
    jq = "${jq}/bin/jq";
  };
  meta = {
    description = "Checks pi extensions against the pinned pi build in checkPhase";
    license = lib.licenses.mit;
  };
} ./setup-hook.sh
