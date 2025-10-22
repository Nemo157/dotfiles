{ lib, buildFHSEnv, fetchurl, stdenv }:

let
  linear-unwrapped = stdenv.mkDerivation {
    pname = "linear-unwrapped";
    version = "1.2.0";

    src = fetchurl {
      url = "https://github.com/schpet/linear-cli/releases/download/v1.2.0/linear-x86_64-unknown-linux-gnu.tar.xz";
      hash = "sha256-Idxct9+GGpbGx2yeBmkNrI+E45M04fieFFKktAPkygI=";
    };

    sourceRoot = "linear-x86_64-unknown-linux-gnu";

    dontFixup = true;

    installPhase = ''
      mkdir -p $out/bin
      cp linear $out/bin/linear
      chmod +x $out/bin/linear
    '';
  };
in
# An FHS env is needed because this is a `deno` binary. It includes extra data just concatenated
# onto the ELF file which gets removed if using `patchelf`, and it tries to use `current_exe()` to
# find the file to read this data from which points to `ld.so` if using a wrapper `ld.so linear`
# script. So an FHS env to provide an interpreter at the path the binary comes with is the only
# solution I found.
buildFHSEnv {
  name = "linear";

  runScript = "${linear-unwrapped}/bin/linear";

  meta = {
    description = "CLI for Linear issue tracking with git and jj support";
    homepage = "https://github.com/schpet/linear-cli";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.nemo157 ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "linear";
  };
}
