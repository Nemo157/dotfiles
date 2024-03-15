{ pkgs-final, pkgs-prev, ... }:

(pkgs-prev.jujutsu.overrideAttrs (jujutsu-final: jujutsu-prev: rec {
  # version using openssh instead of libssh2 for working ed25519-sk support
  version = "6312becabc1e0dfbaad6639f30db83aa8c77ce20";
  src = pkgs-final.fetchFromGitHub {
    owner = "martinvonz";
    repo = "jj";
    rev = version;
    sha256 = "sha256-XdTfRfXdoi8Wv1woZpH93DR0uPLtKwfbPbLBMXk+8Kw=";
  };
  cargoDeps = pkgs-final.rustPlatform.importCargoLock {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "git2-0.18.2" = "sha256-FpHp1zbHRYCINQ72Hrc+jTGE4wQnb6pib1QFQQahQwE=";
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
  rustPlatform = pkgs-final.makeRustPlatform {
    rustc = pkgs-final.rust-bin.stable.latest.minimal;
    cargo = pkgs-final.rust-bin.stable.latest.minimal;
  };
}
