{ lib, fetchFromGitHub, rustPlatform }:
rustPlatform.buildRustPackage rec {
  pname = "sshagmux";
  version = "76f7989d0baa1de4f57284543a87b204908f8fb7";

  src = fetchFromGitHub {
    owner = "Nemo157";
    repo = pname;
    rev = version;
    sha256 = "sha256-7jZPyg3xefpS85obnm5t077ji8oZCU//0sVgKtw+ISo=";
  };

  cargoHash = "sha256-sqIKbPvI90h/Zc/7DCcw3oizjmtkcakC7r0eUEe09eQ=";

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
