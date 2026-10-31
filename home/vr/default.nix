{ lib, config, pkgs, osConfig, ... }:
let
  xr-chaperone-idle = pkgs.writeShellApplication {
    name = "xr-chaperone-idle";
    runtimeInputs = [ pkgs.xr-chaperone pkgs.monado pkgs.gawk ];
    text = ''
      grace=30  # seconds alone before quitting

      xr-chaperone -s &
      pid=$!

      # Client lines from monado-ctl, minus our own
      others() {
        monado-ctl 2>/dev/null | awk -F'\t' '
          /ovly:/ && $NF != "monado-ctl" && $NF != "libmonado" && $NF != "xr-chaperone" { n++ }
          END { print n + 0 }
        '
      }

      alone=0
      while kill -0 "$pid" 2>/dev/null; do
        if [ "$(others)" -gt 0 ]; then alone=0; else alone=$((alone + 5)); fi
        [ "$alone" -ge "$grace" ] && break
        sleep 5
      done

      kill "$pid" 2>/dev/null || true
    '';
  };

  xrizer = pkgs.xrizer.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./xrizer-knuckles-axis3.patch ];
  });

  monado = osConfig.services.monado.package;
in
{
  home.packages = [
    pkgs.wayvr
    pkgs.xr-chaperone
    pkgs.xdg-utils
    pkgs.cameractrls
    (pkgs.callPackage ./mpv-xr.nix {})
    pkgs.unstable.lighthouse-steamvr
  ];

  home.file = {
    # These are required for monado to find the flatpak steam lighthouse binaries.
    ".steam/root".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.var/app/com.valvesoftware.Steam/.local/share/Steam";
    ".steam/steam".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.var/app/com.valvesoftware.Steam/.local/share/Steam";

    # If SteamVR is running, then use that, otherwise connect to monado via xrizer.
    # Needs to be applied to individual games:
    #     ~/.local/bin/vr-launch %command%
    ".var/app/com.valvesoftware.Steam/.local/bin/vr-launch".source = pkgs.writeShellScript "vr-launch" ''
      STEAMVR="$HOME/.local/share/Steam/steamapps/common/SteamVR"
      if ${pkgs.procps}/bin/pgrep -x vrserver >/dev/null; then
        export XR_RUNTIME_JSON="$STEAMVR/steamxr_linux64.json"
      else
        export VR_OVERRIDE="${xrizer}/lib/xrizer"
        export XR_RUNTIME_JSON="${monado}/share/openxr/1/openxr_monado.json"
        export PRESSURE_VESSEL_FILESYSTEMS_RW="$XDG_RUNTIME_DIR/monado_comp_ipc"
      fi
      exec "$@"
    '';
  };

  xdg.configFile."wayvr/theme/gui/watch.xml".source = ./watch.xml;

  systemd.user.services = {
    xr-chaperone = {
      Unit = {
        Description = "xr-chaperone boundary overlay";
        BindsTo = [ "monado.service" ];
        After = [ "monado.service" ];
      };

      Service.ExecStart = "${lib.getExe xr-chaperone-idle}";

      Install.WantedBy = [ "monado.service" ];
    };

    # wayvr = {
    #   Unit = {
    #     Description = "WayVR desktop overlay";
    #     BindsTo = [ "monado.service" ];
    #     After = [ "monado.service" "graphical-session.target" ];
    #   };

    #   Service = {
    #     ExecStart = "${pkgs.wayvr}/bin/wayvr --openxr";
    #     Environment = [
    #       "PATH=${lib.makeBinPath [ pkgs.xdg-utils ]}"
    #     ];
    #     Restart = "on-failure";
    #     RestartSec = 2;
    #   };

    #   Install.WantedBy = [ "monado.service" ];
    # };
  };
}
