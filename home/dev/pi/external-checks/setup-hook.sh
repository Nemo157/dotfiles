# Sourced in the build environment whenever the pi-extension-check setup hook
# is in nativeBuildInputs. Registers a checkPhase run that verifies the package
# under $PWD against the pi build it will run under; see default.nix for what
# the check covers and run-checks.sh for how it runs (on a scratch copy, so
# nothing here touches the sources or the built output).
#
# Everything is derived automatically — no per-package configuration:
#   - pi module tree: baked in as @piRoot@ (the flake-pinned pi-coding-agent);
#   - tsc include globs: the `pi.extensions` entry directories from the
#     package's own package.json (falling back to the whole tree);
#   - the extension's own `#alias/*` imports: rewritten to relative specifiers
#     on the scratch copy (run-checks.sh), since `#`-subpath resolution is
#     fickle across tsc versions;
#   - the extension's runtime deps: $PWD/node_modules, when present.

run_pi_extension_check() {
  # Include exactly what pi loads: the `pi.extensions` entries from the
  # package's own package.json. A file entry (e.g. "./index.ts") includes
  # that file (tsc pulls in the rest of the reachable graph via imports); a
  # directory entry (e.g. pine-of-glass's "./extensions/pi-contextimate")
  # globs its tree. Fall back to the whole tree if there is no entry.
  local include
  include=$(@jq@ -r '
      [ .pi.extensions[]
        | sub("^[.]/"; "") as $e
        | if ($e | contains(".")) then $e else ($e + "/**/*.ts") end
      ] | if length > 0 then . else [ "**/*.ts" ] end | unique
    ' package.json)

  bash @runChecks@ \
    "$PWD" \
    @piRoot@ \
    "$include" \
    @checkPeerVersion@ \
    @rewriteSubpaths@
}

preCheckHooks+=(run_pi_extension_check)
