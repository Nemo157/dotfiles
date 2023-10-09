{ pkgs, ... }: {
  imports = [
    ./drives.nix
    ./kernel.nix
  ];

  hardware.enableRedistributableFirmware = true;

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };

  hardware.firmware = [
    (pkgs.stdenvNoCC.mkDerivation rec {
      pname = "apple-bcm-firmware";
      version = "13.0";
      rev = "1";

      src = pkgs.fetchzip {
        url = "https://github.com/NoaHimesaka1873/${pname}/releases/download/v${version}/${pname}-${version}-${rev}-any.pkg.tar.zst";
        nativeBuildInputs = [ pkgs.zstd ];
        stripRoot = false;
        hash = "sha256-1uOefKdyBW4GJfhkJTjw3zDHDbHK77DrFScIekURpk8=";
      };

      installPhase = ''
        cp -r usr/ "$out/"
      '';
    })
  ];
}
