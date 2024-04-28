{ ts, config, pkgs, lib, ... }: {

  services.openssh = rec {
    enable = true;
    ports = [ 59127 ];
    openFirewall = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
    };
  };

}
