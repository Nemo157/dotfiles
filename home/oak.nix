{ lib, config, pkgs, ... }: {
  imports = [
    ./cli
    ./dev
    ./desktop
    ./xdg.nix
    ./age.nix
    ./wluma.nix
    ./veecle
  ];

  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    iamb
    wluma
  ];

  xdg.configFile = {
    "wireplumber/wireplumber.conf.d/51-config.conf".text = ''
      monitor.bluez.rules = [
        {
          matches = [
            { device.description = "J55" }
          ]
          actions = {
            update-props = {
              media-role.use-headset-profile = false
              bluetooth.autoswitch-to-headset-profile = false
              bluez5.auto-connect = [ a2dp_sink ]
            }
          }
        }
      ]
    '';

    "pipewire/pipewire.conf.d/92-j55-mono.conf".text = ''
      context.modules = [
        {
          name = libpipewire-module-combine-stream
          args = {
            combine.mode = sink
            node.name = "stereo-to-mono.j55"
            node.description = "Mono J55"
            combine.latency-compensate = false
            combine.props = {
              audio.position = [ MONO ]
            }
            stream.props = {
              stream.dont-remix = true
            }
            stream.rules = [
              {
                matches = [
                  {
                    media.class = "Audio/Sink"
                    node.description = "J55"
                  }
                ]
                actions = {
                  create-stream = {
                    audio.position = [ FL FR ]
                    combine.audio.position = [ MONO ]
                  }
                }
              }
            ]
          }
        }
      ]
    '';
  };
}
