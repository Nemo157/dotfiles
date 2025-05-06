{ lib, fetchCrate, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "cargo-dl";
  version = "0.1.5";

  src = fetchCrate {
    inherit pname version;
    sha256 = "sha256-Rmgn1oTFKZ5wTE6akfRuPwYQu5ePiJWuJduHfqF6Wpo=";
  };

  cargoHash = "sha256-q3SUCKax8SpKbC15+T+3jnGcww8pNUiXXt7IAvsNpNQ=";

  meta = with lib; {
    description = "Cargo subcommand for downloading crate sources";
    homepage = src.meta.homepage;
    license = with licenses; [ mit asl20 ];
    maintainers = [ maintainers.nemo157 ];
  };
}
