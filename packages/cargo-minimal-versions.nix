{ lib, fetchFromCratesIo, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "cargo-minimal-versions";
  version = "0.1.20";

  src = fetchFromCratesIo {
    inherit pname version;
    sha256 = "sha256-6uJ/QXuDJ55baWGuzP8IIsezM1QSEeKOxN+0jm6Or50=";
  };

  cargoSha256 = "sha256-Zcr+xWNFPJhtfJF8pl+KUN/ZSVa25mSbdXHMqY6OMv0=";

  meta = with lib; {
    description = "Cargo subcommand for proper use of -Z minimal-versions";
    homepage = src.meta.homepage;
    license = with licenses; [ mit asl20 ];
    maintainers = [ maintainers.nemo157 ];
  };
}
