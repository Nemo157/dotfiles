{ lib, fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "cargo-dl";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "Nullus157";
    repo = pname;
    rev = version;
    sha256 = "sha256-emSGhMgKyXZL3kWQGgvrLViOJY0F8y1Swem/VdMJx4o=";
  };

  cargoHash = "sha256-mkRZtC6JjsJxQ4DTjS2qw2y1opFIMt39eEMR1DurgAM=";

  meta = with lib; {
    description = "Cargo subcommand for downloading crate sources";
    homepage = src.meta.homepage;
    license = with licenses; [ mit asl20 ];
    maintainers = [ maintainers.nemo157 ];
  };
}
