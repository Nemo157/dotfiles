{ pkgs, lib, ... }:
let
  wrap-rust = pkgs.callPackage ./wrap-rust.nix {};
  setup-xdg-cargo-home = pkgs.writeShellApplication {
    name = "setup-xdg-cargo-home";
    text = lib.readFile ./setup-xdg-cargo-home;
  };
in {
  extraBuildInputs ? [],
  rust-toolchain ? (pkgs.rust-bin.selectLatestNightlyWith (toolchain:
    toolchain.default.override {
      extensions = [
        "rust-src"
        "rustc-codegen-cranelift-preview"
      ];
    }
  )),
}: pkgs.mkShell {
  buildInputs = with pkgs; [
    # Rust itself
    (wrap-rust rust-toolchain)

    # Dev utilities
    bacon
    cargo-deny
    cargo-dl
    cargo-doc-like-docs-rs
    cargo-expand
    cargo-fuzz
    cargo-hack
    cargo-minimal-versions
    cargo-nextest
    cargo-rubber
    cargo-supply-chain
    cargo-sweep
    cargo-udeps
    cargo-vet
    cargo-watch

    # Common C tools
    cmake
    pkg-config

    # Common "system" dependencies
    openssl
  ] ++ extraBuildInputs;

  shellHook = ''
    export RUST_BACKTRACE=1

    ${lib.getExe setup-xdg-cargo-home}

    export CARGO_BUILD_TARGET=x86_64-unknown-linux-gnu
    export CARGO_BUILD_TARGET_DIR="$CARGO_HOME/target/shared"

    rustflags=(
      "--cap-lints=warn"
      # "-Clink-self-contained=+linker"
      # "-Clinker-flavor=gnu-lld-cc"
      "-Zunstable-options"
      "-Ctarget-cpu=native"
      "-Zrandomize-layout"
      "-Zthreads=8"
    )

    declare -A remap=(
      ["${rust-toolchain}/lib/rustlib/src/rust/library"]="rust"
      ["$CARGO_HOME"]="cargo"
      ["$CARGO_HOME/git/checkouts"]="git"
      ["$CARGO_HOME/registry/src"]="registry"
      ["$CARGO_HOME/registry/src/index.crates.io-6f17d22bba15001f"]="crates.io"
    )

    e=$'\e'
    for path in "''${!remap[@]}"
    do
      rustflags+=("--remap-path-prefix=$path=$e[36;1m''${remap[$path]}$e[0m")
    done

    export CARGO_HOST_RUSTFLAGS="''${rustflags[*]}"
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS="''${rustflags[*]}"

    export CARGO_PROFILE_DEV_CODEGEN_BACKEND=cranelift

    export CARGO_UNSTABLE_CODEGEN_BACKEND=true
    export CARGO_UNSTABLE_HOST_CONFIG=true
    export CARGO_UNSTABLE_TARGET_APPLIES_TO_HOST=true
    export CARGO_TARGET_APPLIES_TO_HOST=false
    export CARGO_UNSTABLE_BUILD_STD=std
    export CARGO_UNSTABLE_TRIM_PATHS=true

    # Some crates disable nightly feature detection when this is set
    export RUSTC_STAGE=1
  '';
}
