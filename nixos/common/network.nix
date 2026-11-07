{
  networking = {
    useNetworkd = true;
  };

  systemd.network = {
    enable = true;
  };

  services.resolved = {
    enable = true;
  };

  # https://github.com/NixOS/nixpkgs/issues/576485
  security.pki.caCertificateBlacklist = [
    # CVE-2026-111943
    "Comodo AAA Services root"
  ];
}
