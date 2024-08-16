{ pkgs-unstable, pkgs-final, pkgs-prev, ... }:

(pkgs-prev.jujutsu.overrideAttrs (jujutsu-final: jujutsu-prev: rec {
  # version using openssh instead of libssh2 for working ed25519-sk support
  version = "9cf51e4b8c4d96180ec010541579b00686365934";
  src = pkgs-final.fetchFromGitHub {
    owner = "martinvonz";
    repo = "jj";
    rev = version;
    sha256 = "sha256-Ck69lkyT/vKyyIfd6/UNkChD/WqxpLGtsno+gr8QS4Q=";
  };
  cargoDeps = pkgs-final.rustPlatform.importCargoLock {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "git2-0.19.0" = "sha256-fV8dFChGeDhb20bMyqefpAD5/+raQQ2sMdkEtlA1jaE=";
    };
  };
  buildInputs = with pkgs-final; [
    openssl
    zstd
    # nixpkgs libgit2 doesn't have openssh support built in
    # libgit2
    zlib
  ];
  nativeBuildInputs = jujutsu-prev.nativeBuildInputs ++ [pkgs-final.openssh];
  cargoBuildFlags = jujutsu-prev.cargoBuildFlags ++ ["-vv"];
})).override {
  rustPlatform = pkgs-unstable.rustPlatform;
}
