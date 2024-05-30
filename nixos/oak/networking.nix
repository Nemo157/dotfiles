{ config, ... }: {
  age.secrets.wlan-psk.file = ../wlan-psk.age;

  networking = {
    hostName = "oak";
    wireless = {
      enable = true;
      userControlled.enable = true;
      environmentFile = config.age.secrets.wlan-psk.path;
      networks = {
        NineEyes.psk = "@PSK_NINE_EYES@";
        Drivery.psk = "@PSK_DRIVERY@";
      };
    };
  };
}
