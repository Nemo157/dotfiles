{
  lib,
  stdenv,
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
# `pi.extensions` list pi reads).
#
# Built as an ordinary stdenv derivation (not runCommand) so the standard
# phases behave properly: unpackPhase unpacks the fetchzip'ed `src` and cd's
# into it, checkPhase runs the pi-extension-check gate against the pinned pi,
# and installPhase ships the source verbatim as the package root. (A bare
# runCommand would run its build command in an empty dir, never unpack `src`,
# and — more subtly — skip checkPhase entirely.)
#
# Audited at 0.10.1: the four extensions are pure TUI/accounting overlays.
# They register no tools and never spawn processes, open sockets or write
# files — the only node builtins used are `node:os` (homedir, for path
# shortening), `node:crypto` (hashing prompt prefixes) and `node:fs` reads of
# their own JSON config plus files touched by write/edit calls (to render
# diffs). Re-check this when bumping; bumped to 0.18.4 without a repeat audit,
# the checkPhase typecheck against the pinned pi is the current gate.
#
# Bumping: update `version`/`rev` to the new `v<version>` tag, set `hash` to
# `lib.fakeHash`, run `colmena build` once and paste the reported hash back in
# (the failed build also names the unpacked source path, handy for re-auditing
# before the config actually uses it). A pi version bump re-runs the checkPhase
# against the new pi types; if it fails, the extension needs a bump too.
let
  version = "0.18.4";
in
stdenv.mkDerivation {
  pname = "pine-of-glass";
  inherit version;

  src = fetchFromGitHub {
    owner = "tmustier";
    repo = "pine-of-glass";
    rev = "v${version}";
    hash = "sha256-bic79MtKciK0/hk8FSonxJMW23XY6yZej/jX1Eke7f8=";
  };

  # contextimate cycles its panel on Pi's ctrl+o (app.tools.expand), so
  # ctrl+o walks a 2x3 product of tool expansion and panel views. Move the
  # cycling to its own ctrl+shift+o shortcut.
  # --replace-fail makes a bump that moves this code fail the build.
  # Continuation lines of multi-line literals carry 4 extra spaces: the ''
  # string strips the common 4-space indent from every line, theirs included.
  postPatch = ''
    substituteInPlace extensions/pi-contextimate/index.ts \
      --replace-fail '    this.setMode(nextMode(this.mode));' \
        '    // Patched out: cycling lives on its own shortcut (ctrl+shift+o).' \
      --replace-fail '  pi.registerCommand("contextimate", {' \
        '  pi.registerShortcut("ctrl+shift+o", {
        description: "contextimate: cycle the [Contextimate] view",
        handler: async (ctx) => {
          if (!ctx.hasUI) return;
          const mode = nextMode(g.__piContextimateMode ?? DEFAULT_MODE);
          g.__piContextimateMode = mode;
          g.__piContextimateBlock?.setMode(mode);
          g.__piContextimateTui?.requestRender(true);
        },
      });

      pi.registerCommand("contextimate", {'

    substituteInPlace extensions/pi-contextimate/render.ts \
      --replace-fail 'keyText("app.tools.expand") || "Ctrl+O"' '"ctrl+shift+o"'
  '';

  nativeBuildInputs = [ piExtensionCheck ];

  # stdenv defaults doCheck to false; without this the check never runs.
  doCheck = true;

  # The package root is the source tree (no build step): install it verbatim.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r . "$out/"
    runHook postInstall
  '';

  meta = {
    description = "Observability extensions for the Pi coding agent";
    homepage = "https://github.com/tmustier/pine-of-glass";
    license = lib.licenses.mit;
  };
}
