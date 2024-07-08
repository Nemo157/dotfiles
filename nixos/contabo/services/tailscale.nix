{ config, pkgs, lib, ... }: {

  services.tailscale = {
    useRoutingFeatures = "server";
  };

}
