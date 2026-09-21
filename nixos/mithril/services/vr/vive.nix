{ lib, pkgs, config, ... }:
let
  systemctl = "${config.systemd.package}/bin/systemctl";
  lighthouse = lib.getExe pkgs.lighthouse-steamvr;
in
{
  # Tag the Vive so systemd creates a device unit for it, give that unit a
  # predictable name, and have it pull in a target.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="28de", ATTR{idProduct}=="2000", \
      TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/vivehmd", \
      ENV{SYSTEMD_USER_WANTS}+="vr-available.target vr-present.service"

    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="35bd", ATTR{idProduct}=="0101", \
      TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/vivehmd", \
      ENV{SYSTEMD_USER_WANTS}+="vr-available.target vr-present.service"
  '';

  systemd.user = {
    targets.vr-available = {
      description = "Headset connected";
    };

    # Follows the device exactly; arms/disarms the grace timer
    services.vr-present = {
      bindsTo = [ "dev-vivehmd.device" ];
      after = [ "dev-vivehmd.device" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "-${systemctl} --user stop vr-grace.timer";
        ExecStop = "-${systemctl} --user --no-block restart vr-grace.timer";
      };
    };

    # Delays stopping the target in case the HMD comes back (e.g. when it self-resets after monado stops)
    timers.vr-grace = {
      timerConfig.OnActiveSec = "60s";
    };
    services.vr-grace = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${systemctl} --user stop vr-available.target";
      };
    };

    # Don't start the socket at login; tie it to the device instead.
    sockets.monado = {
      wantedBy = lib.mkForce [ "vr-available.target" ];
      partOf = [ "vr-available.target" ];
      after = [ "vr-available.target" ];
    };

    # Stop the service if the headset is unplugged mid-session.
    services.monado.partOf = [ "vr-available.target" ];

    services.lighthouses = {
      description = "Power base stations with the headset";
      wantedBy = [ "vr-available.target" ];
      partOf = [ "vr-available.target" ];
      after = [ "vr-available.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lighthouse} --state ON --bsid 05697446";
        ExecStop = "${lighthouse} --state OFF --bsid 05697446";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStartSec = 60;
        TimeoutStopSec = 60;
      };
    };
  };
}
