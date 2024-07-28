{ lib, pkgs, ... }:
let
  ddcutil-user-configs = pkgs.symlinkJoin {
    name = "ddcutil-user-configs";
    paths = lib.mapAttrsToList (name: text: pkgs.writeTextDir "share/ddcutil/${name}.mccs" text) {
      AOC-U27G3X-45856 = ''
        MFG_ID       AOC - UNK
        MODEL        U27G3X
        PRODUCT_CODE 45856

        FEATURE_CODE x14 Color Temp
            ATTRS NC RW
            VALUE x01 sRGB
            VALUE x05 Warm
            VALUE x06 Normal
            VALUE x08 Cool
            VALUE x0b User

        FEATURE_CODE xdc Game Mode
            ATTRS NC RW
            VALUE x00 Off
            VALUE x0b FPS
            VALUE x0c RTS
            VALUE x0d Racing
            VALUE x0e Gamer 1
            VALUE x0f Gamer 2
            VALUE x10 Gamer 3

        FEATURE_CODE xe6 FreeSync Mode
            ATTRS NC RO
            VALUE x00 Off
            VALUE x01 On
      '';
    };
  };
in {
  hardware = {
    i2c.enable = true;
  };

  environment = {
    systemPackages = [
      pkgs.ddcutil
      ddcutil-user-configs
    ];
    pathsToLink = [
      "/share/ddcutil"
    ];
};
}
