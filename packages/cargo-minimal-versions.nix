{ lib, fetchCrate, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "cargo-minimal-versions";
  version = "0.1.20";

  src = fetchCrate {
    inherit pname version;
    sha256 = "sha256-6uJ/QXuDJ55baWGuzP8IIsezM1QSEeKOxN+0jm6Or50=";
  };

  cargoHash = "sha256-1oK4UpSLDPKALOKIc2KY+HO1Wv0SdhZSy7SrY+hbTJ0=";

  meta = with lib; {
    description = "Cargo subcommand for proper use of -Z minimal-versions";
    homepage = src.meta.homepage;
    license = with licenses; [ mit asl20 ];
    maintainers = [ maintainers.nemo157 ];
  };
}
