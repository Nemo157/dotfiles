{ lib, fetchFromGitHub, rustPlatform, libusb1, pkg-config }:

rustPlatform.buildRustPackage rec {
  pname = "AnnePro2-Tools";
  version = "a13b82c362e928f4f867cb47d3644e07768b40a8";

  src = fetchFromGitHub {
    owner = "OpenAnnePro";
    repo = pname;
    rev = version;
    sha256 = "sha256-7zYXsh4p/Ys6e970Tquwvxs8/mL3ZN0xvGtJyAItl9Y=";
  };

  cargoHash = "sha256-K+4YOJuhDQlLuZvnriKBkwGnOO913YGiDt8UXw5ShtQ=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libusb1
  ];
}
