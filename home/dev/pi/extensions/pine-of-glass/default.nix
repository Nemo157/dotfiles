{
  runCommand,
  fetchFromGitHub,
  # Build-time check hook from the overlay (home/dev/pi/external-checks):
  # verifies this extension against the flake-pinned pi build (peerDependency
  # ranges + a tsc run against pi's types). Its peer ranges are all "*", so
  # here the typecheck is the real check.
  piExtensionCheck,
}:

# pine-of-glass (https://github.com/tmustier/pine-of-glass), a pi package
# bundling four observability / context-management extensions:
# pi-contextimate, pi-traceline, pi-cachemire and pi-meantime.
#
# The package has no runtime dependencies at all — only optional peer deps on
# the @earendil-works/pi-* modules that the host pi already provides — so
# there is nothing to build and no node_modules to materialize: the checked
# out source *is* the package root (its package.json carries the
# `pi.extensions` list pi reads). The derivation only copies the checkout and
# lets the checkPhase hook verify the sources against the pinned pi build.
#
# Audited at 0.10.1: the four extensions are pure TUI/accounting overlays.
# They register no tools and never spawn processes, open sockets or write
# files — the only node builtins used are `node:os` (homedir, for path
# shortening), `node:crypto` (hashing prompt prefixes) and `node:fs` reads of
# their own JSON config plus files touched by write/edit calls (to render
# diffs). Re-check this when bumping.
#
# Bumping: update `version`/`rev` to the new `v<version>` tag, set `hash` to
# `lib.fakeHash`, run `colmena build` once and paste the reported hash back in
# (the failed build also names the unpacked source path, handy for re-auditing
# before the config actually uses it). A pi version bump re-runs the checkPhase
# against the new pi types; if it fails, the extension needs a bump too.
let
  version = "0.10.1";
in
runCommand "pine-of-glass-${version}"
  {
    src = fetchFromGitHub {
      name = "pine-of-glass-${version}";
      owner = "tmustier";
      repo = "pine-of-glass";
      rev = "v${version}";
      hash = "sha256-4Q4pnQhNyjVp9/DJ9wiEYcep75RS/yywtBWHd3JTvqw=";
    };

    nativeBuildInputs = [ piExtensionCheck ];

    # stdenv defaults doCheck to false; without this the check never runs.
    doCheck = true;
  }
  ''
    # checkPhase (the pi-extension-check hook) verifies $PWD — the unpacked
    # source, i.e. the exact tree shipped as the package root — against the
    # pinned pi build. Nothing writes here; the check runs on a scratch copy.
    cp -r . $out
  ''
