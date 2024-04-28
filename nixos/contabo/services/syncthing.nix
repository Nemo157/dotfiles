{ ts, config, pkgs, lib, ... }: {

  networking.firewall.allowedTCPPorts = [ 8384 ];

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    guiAddress = "${ts.self.ip}:8384";
    settings = {
      gui.tls = true;
      defaults.folder.type = "receiveencrypted";
    };
  };

}
