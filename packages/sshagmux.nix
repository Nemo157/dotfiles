{ lib, fetchFromGitHub, rustPlatform }:
rustPlatform.buildRustPackage rec {
  pname = "sshagmux";
  version = "b8ada819a5332b9603f561521fdc5176a785cc61";

  src = fetchFromGitHub {
    owner = "Nemo157";
    repo = pname;
    rev = version;
    sha256 = "sha256-kzJp5VR97xI/AKC5Ji2JhQombpbiaZdiHFQjA8QJQ2U=";
  };

  cargoHash = "sha256-1+5aF/wj+XPatliRWMUj22B+J1dF//yRexTljIdk68I=";

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
