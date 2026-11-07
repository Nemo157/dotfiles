{ maintainers, inputs }:
final: prev:
let
  args = {
    # nix flake check doesn't like me renaming the function arguments,
    # so we have to alias here....
    pkgs-final = final;
    pkgs-prev = prev;
  };
  intersectAttrs = builtins.intersectAttrs;
  functionArgs = builtins.functionArgs;
  callOverlay = path: (import path) args;
in
{
  freetube = final.unstable.freetube;

  maintainers = prev.maintainers // maintainers;

  # https://github.com/Leseratte10/acsm-calibre-plugin/issues/68#issuecomment-2162686156
  calibre = final.symlinkJoin {
    inherit (prev.calibre) name;
    paths = [
      (final.writeShellApplication {
        name = "calibre";
        text = ''
          export ACSM_LIBCRYPTO=${final.openssl.out}/lib/libcrypto.so
          export ACSM_LIBSSL=${final.openssl.out}/lib/libssl.so
          ${prev.calibre}/bin/calibre
        '';
      })
      prev.calibre
    ];
  };

  cargo-llvm-cov = final.callPackage (
    { rustPlatform }:
    rustPlatform.buildRustPackage rec {
      pname = "cargo-llvm-cov";
      version = "0.6.15";
      src = final.fetchCrate {
        inherit pname version;
        sha256 = "sha256-NOgo36hyWhdJq1It24gwn9Pu9jbDPOiWsOlvaWPRgJc=";
      };
      cargoHash = "sha256-MfccCi8nw/sz+5WfVc4ge1D57rISJbwI6MvVPA/aBDk=";
      doCheck = false;
    }
  ) { };

  jujutsu = final.unstable.jujutsu;

  # Build-time check hook for externally-sourced pi extensions: verifies the
  # extension against the flake-pinned pi package (peerDependency ranges + a
  # tsc run against pi's types) in its derivation's checkPhase. See
  # home/dev/pi/external-checks/default.nix. The pi root is baked in from
  # unstable.pi-coding-agent — the same package config.programs.pi.package
  # resolves to — so any pi bump re-checks every extension before deploy.
  piExtensionCheck = final.callPackage ./../home/dev/pi/external-checks {
    pi-coding-agent = final.unstable.pi-coding-agent;
    # Upstream extensions target typescript ^6/^7; use the modern native tsc
    # (the Go port) so `#alias/*` subpath imports resolve the way upstream CI
    # sees them, rather than the legacy 5.x tsc.
    typescript = final.unstable.typescript_7;
  };

  ffmpeg-fdk-aac = prev.ffmpeg.override {
    ffmpegVariant = "headless";
    withUnfree = true;
    withFdkAac = true;
  };

  yt-dlp = prev.yt-dlp.overrideAttrs (old: {
    version = "nightly-${inputs.yt-dlp-src.shortRev}";
    src = inputs.yt-dlp-src;
    # doCheck = false;          # master occasionally has failing tests
    # pythonRelaxDeps = true;   # master sometimes bumps yt-dlp-ejs minimums
  });
}
// import ../packages { pkgs = final; }
