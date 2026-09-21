{
  lib,
  stdenv,
  fetchFromSourcehut,
  pkg-config,
  wayland-scanner,
  xxd,
  makeWrapper,
  wayland,
  wayland-protocols,
  libGL,
  glew,
  openxr-loader,
  mpv-unwrapped,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "mpv-xr";
  version = "0-unstable-2025-05-30"; # set to the date of `rev`

  src = fetchFromSourcehut {
    owner = "~shironeko";
    repo = "mpv-xr";
    rev = "f6dca8136a0600ae58a0e971ded9aa1c287922d4";
    hash = "sha256-vPcu0v1DapZhzztSLVH3Xs/R51iIL/v3VdVfzZYyV4U=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
    xxd # used to embed shaders into the binary
    makeWrapper
  ];

  buildInputs = [
    wayland
    wayland-protocols
    wayland-scanner
    libGL
    glew
    openxr-loader
    mpv-unwrapped.dev
  ];

  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
    "PKG_CONFIG=${stdenv.cc.targetPrefix}pkg-config"
  ];

  enableParallelBuilding = true;

  # The upstream Makefile has no install target, so install by hand.
  installPhase = ''
    runHook preInstall
    install -Dm755 mpv-xr -t $out/bin
    install -Dm644 README* -t $out/share/doc/mpv-xr 2>/dev/null || true
    runHook postInstall
  '';

  # The OpenXR loader dlopens the runtime (Monado, WiVRn, etc.), which in
  # turn needs libGL/libEGL; make sure the vendor libs are reachable.
  postFixup = ''
    wrapProgram $out/bin/mpv-xr \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libGL openxr-loader ]}
  '';

  meta = {
    description = "Stereoscopic and 360° video player for VR headsets using OpenXR and libmpv";
    homepage = "https://sr.ht/~shironeko/mpv-xr/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "mpv-xr";
  };
})
