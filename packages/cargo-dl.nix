{ lib, fetchCrate, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "cargo-dl";
  version = "0.1.4";

  src = fetchCrate {
    inherit pname version;
    sha256 = "sha256-txSRmOr3tYw72xI5Dqt/y1EboaqFWEMN+lASVXLNdgQ=";
  };

  cargoHash = "sha256-mkRZtC6JjsJxQ4DTjS2qw2y1opFIMt39eEMR1DurgAM=";

  meta = with lib; {
    description = "Cargo subcommand for downloading crate sources";
    homepage = src.meta.homepage;
    license = with licenses; [ mit asl20 ];
    maintainers = [ maintainers.nemo157 ];
  };
}
