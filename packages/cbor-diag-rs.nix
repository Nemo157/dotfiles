{ lib, fetchCrate, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "cbor-diag-cli";
  version = "0.1.8";

  src = fetchCrate {
    inherit pname version;
    sha256 = "sha256-c3YY1/P3nP1KQRjSeYHyMulfROzPyMiu3PsslFVTv9Q=";
  };

  cargoHash = "sha256-p5szEl+AtYnMzkwzu39ary27KAnn2ft7fvJE0InWdvI=";

  meta = with lib; {
    homepage = src.meta.homepage;
    license = with licenses; [ mit asl20 ];
    maintainers = [ maintainers.nemo157 ];
  };
}
