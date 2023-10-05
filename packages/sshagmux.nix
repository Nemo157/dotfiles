{ lib, fetchFromGitHub, rustPlatform }:
rustPlatform.buildRustPackage rec {
  pname = "sshagmux";
  version = "6e209ecfb3fa93f7b4b3c449bf08865e78a66b3b";

  src = fetchFromGitHub {
    owner = "Nemo157";
    repo = pname;
    rev = version;
    sha256 = "sha256-4xsCijYyuopnPTvu5El812MOxvRg1p074kzZeNt37Po=";
  };

  cargoHash = "sha256-3DvwUFghQ8gEbaw0xrU+MfMv3XTBkGpTiaTt8osSJ7g=";

  postInstall = ''
    mkdir -p $out/share/systemd/user $out/ssh
    cp configs/sshagmux.{service,socket} $out/share/systemd/user/
    substituteInPlace $out/share/systemd/user/sshagmux.service \
      --replace '%h/.cargo/bin/sshagmux' $out/bin/sshagmux
    cp configs/ssh.rc $out/ssh/rc
    substituteInPlace $out/ssh/rc \
      --replace '~/.cargo/bin/sshagmux' $out/bin/sshagmux
  '';

  meta = with lib; {
    description = "An ssh-agent multiplexer";
    homepage = src.meta.homepage;
    license = with licenses; [ mit asl20 ];
    maintainers = [ maintainers.nemo157 ];
  };
}
