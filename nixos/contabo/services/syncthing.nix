{ name, ts, syncthing, config, pkgs, lib, ... }: {

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8384 22000 ];

  services.syncthing = {
    enable = true;
    guiAddress = "${ts.ips.${name}}:8384";
    # looks like just re-auto-accepting folders doesn't work,
    # they need to persist after reconfiguring
    overrideFolders = false;
    settings = {
      gui = {
        tls = true;
        user = "Decal";
        password = "$2y$15$P3JRw9KG2YyAcbVZJG.T8.c.RB.mAJerIRTpf/T2KdMZ/tITNuS2q";
      };
      defaults.folder.type = "receiveencrypted";
      devices = lib.mapAttrs (host: id: {
        inherit id;
        addresses = [ "quic://${host}.${ts.domain}:22000" ];
        autoAcceptFolders = true;
      }) syncthing;
    };
  };

}
