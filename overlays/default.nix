{ pkgs-unstable, maintainers }: final: prev: let
  args = {
    inherit pkgs-unstable;
    # nix flake check doesn't like me renaming the function arguments,
    # so we have to alias here....
    pkgs-final = final;
    pkgs-prev = prev;
  };
  intersectAttrs = builtins.intersectAttrs;
  functionArgs = builtins.functionArgs;
  callOverlay = path: (import path) args;
in {
  rofi-wayland-unwrapped = callOverlay ./rofi-wayland.nix;
  rofi = final.rofi-wayland;

  freetube = callOverlay ./freetube.nix;

  maintainers = prev.maintainers // maintainers;

  # No release in over 2 years, with many many commits since :ferrisPensive:
  beets = prev.beets-unstable;

  # broken with 1.80 changes
  # starship = callOverlay ./starship.nix;

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

  unstable = pkgs-unstable;

  cargo-llvm-cov = final.callPackage ({ rustPlatform }: rustPlatform.buildRustPackage rec {
    pname = "cargo-llvm-cov";
    version = "0.6.15";
    src = final.fetchCrate {
      inherit pname version;
      sha256 = "sha256-NOgo36hyWhdJq1It24gwn9Pu9jbDPOiWsOlvaWPRgJc=";
    };
    cargoHash = "sha256-MfccCi8nw/sz+5WfVc4ge1D57rISJbwI6MvVPA/aBDk=";
    doCheck = false;
  }) {};

} // import ../packages { pkgs = final; }
