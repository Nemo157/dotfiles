{ name, ts, config, pkgs, lib, ... }: {

  networking.firewall.allowedTCPPorts = [ 8384 ];

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    guiAddress = "${ts.ips.${name}}:8384";
    settings = {
      gui.tls = true;
      defaults.folder.type = "receiveencrypted";
    };
  };

}
