{ config, pkgs, lib, ... }: {

  networking.firewall.allowedTCPPorts = [ 4001 ];
  networking.firewall.allowedUDPPorts = [ 4001 ];

  networking.interfaces.ens18.ipv6.addresses = [
    {
      address = "2a02:c207:2020:2848:8b22:32d1:49d2:1469";
      prefixLength = 64;
    }
  ];

  services.kubo = {
    enable = true;
    emptyRepo = true;
    localDiscovery = false;
    settings = {
      Addresses.Swarm = [
        "/ip6/2a02:c207:2020:2848:8b22:32d1:49d2:1469/tcp/4001"
        "/ip6/2a02:c207:2020:2848:8b22:32d1:49d2:1469/udp/4001/quic"
      ];
      Bootstrap = [
        "/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN"
        "/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa"
        "/dnsaddr/bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb"
        "/dnsaddr/bootstrap.libp2p.io/p2p/QmcZf59bWwK5XFi76CZX8cbJ4BhTzzA3gU1ZjYZcYW3dwt"
        "/ip6/2604:a880:1:20::203:d001/tcp/4001/p2p/QmSoLPppuBtQSGwKDZT2M73ULpjvfd3aZ6ha4oFGL1KrGM"
        "/ip6/2400:6180:0:d0::151:6001/tcp/4001/p2p/QmSoLSafTMBsPKadTEgaXctDQVcqN88CNLHXMkTNwMKPnu"
        "/ip6/2604:a880:800:10::4a:5001/tcp/4001/p2p/QmSoLV4Bbm51jM9C4gDYZQ9Cy3U6aXMJDAbzgu2fzaDs64"
        "/ip6/2a03:b0c0:0:1010::23:1001/tcp/4001/p2p/QmSoLer265NRgSp2LA3dPaeykiS1J6DifTC88f5uVQKNAd"
      ];
      Swarm.AddrFilters = [
        "/ip4/0.0.0.0/ipcidr/0"
      ];
      Datastore.StorageMax = "50GB";
    };
  };

}
