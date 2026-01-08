{
  pkgs,
  lib,
  extraBuildInputs ? [],
  rust-toolchain ? (pkgs.rust-bin.selectLatestNightlyWith (toolchain:
    toolchain.minimal.override {
      extensions = [
        "rust-src"
        "rustc-codegen-cranelift-preview"
        "miri"
        "clippy"
        "rustfmt"
      ];
    }
  )),
  custom ? true,
  ...
}:
let
  wrap-rust = pkgs.callPackage ./wrap-rust.nix {};
  cargo-upgrade = pkgs.writeShellApplication {
    name = "cargo-upgrade";
    text = ''
      echo cargo-edit does not support the sparse registry
      exit 1
    '';
  };
  rustup = pkgs.writeShellApplication {
    name = "rustup";
    text = ''
      if [ "$1" = "run" ]
      then
        # rustup run <toolchain> <args...>
        shift 2
        exec "$@"
      else
        printf 'unsupported rustup shim:\n    rustup'
        printf ' %q' "$@"
        printf '\n'
        exit 1
      fi
    '';
  };
in pkgs.mkShell {
  buildInputs = with pkgs; [
    # Rust itself
    (if custom then (wrap-rust rust-toolchain) else rust-toolchain)

    # Dev utilities
    cargo-audit
    cargo-deny
    cargo-doc-like-docs-rs
    cargo-expand
    cargo-fuzz
    cargo-hack
    cargo-nextest
    cargo-outdated
    cargo-semver-checks
    cargo-supply-chain
    cargo-sweep
    cargo-udeps
    cargo-upgrade
    cargo-vet
    cargo-watch
    rustup

    # Common C tools
    cmake
    pkg-config

    # Common "system" dependencies
    openssl
  ] ++ extraBuildInputs;

  passthru = {
    inherit rust-toolchain;
  };

  shellHook = if custom then ''
    rustflags=(
      "--cap-lints=warn"
      "-Clink-arg=-fuse-ld=${lib.getExe pkgs.mold-wrapped}"
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
    export CARGO_HOST_LINKER="${lib.getExe pkgs.clang}"
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS="''${rustflags[*]}"
    export CARGO_TARGET_APPLIES_TO_HOST=false
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="${lib.getExe pkgs.clang}"

    export CARGO_PROFILE_DEV_CODEGEN_BACKEND=cranelift
    export CARGO_PROFILE_DEV_PANIC=abort

    export CARGO_BUILD_BUILD_DIR="{cargo-cache-home}/target/build/{workspace-path-hash}"

    export CARGO_UNSTABLE_BUILD_DIR=true
    export CARGO_UNSTABLE_BUILD_STD=std,panic_abort
    export CARGO_UNSTABLE_CHECK_CFG=true
    export CARGO_UNSTABLE_CODEGEN_BACKEND=true
    export CARGO_UNSTABLE_GITOXIDE_CHECKOUT=true
    export CARGO_UNSTABLE_GITOXIDE_FETCH=true
    export CARGO_UNSTABLE_GITOXIDE_INTERNAL_USE_GIT2=false
    export CARGO_UNSTABLE_GITOXIDE_LIST_FILES=true
    export CARGO_UNSTABLE_GIT_SHALLOW_DEPS=true
    export CARGO_UNSTABLE_GIT_SHALLOW_INDEX=true
    export CARGO_UNSTABLE_HOST_CONFIG=true
    export CARGO_UNSTABLE_PANIC_ABORT_TESTS=true
    export CARGO_UNSTABLE_RUSTC_UNICODE=true
    export CARGO_UNSTABLE_TARGET_APPLIES_TO_HOST=true
    export CARGO_UNSTABLE_TRIM_PATHS=true

    # Some crates disable nightly feature detection when this is set
    export RUSTC_STAGE=1
  '' else "";
}
