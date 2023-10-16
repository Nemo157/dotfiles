{ config, ... }: {
  age.secrets.wlan-psk.file = ../wlan-psk.age;

  networking.hostName = "zinc";
  networking.wireless = {
    enable = true;
    userControlled = {
      enable = true;
    };
    environmentFile = config.age.secrets.wlan-psk.path;
    networks = {
      NineEyes.psk = "@PSK_NINE_EYES@";
      StuffnesslyZwei.psk = "@PSK_STUFFNESSLY@";
    };
  };
}
