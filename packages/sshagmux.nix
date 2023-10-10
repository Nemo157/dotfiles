{ lib, fetchFromGitHub, rustPlatform }:
rustPlatform.buildRustPackage rec {
  pname = "sshagmux";
  version = "b8d4209878f1e3b9ed9c61756401e30263d97a6e";

  src = fetchFromGitHub {
    owner = "Nemo157";
    repo = pname;
    rev = version;
    sha256 = "sha256-1ULjG3d3KzwgOB+WsL17MLVzmqNemMwqkkV9tth9L1I=";
  };

  cargoHash = "sha256-b0DsWrJe8XyJHkhVuGQdSuVu9QKrnZEysOwcYG42zQg=";

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
