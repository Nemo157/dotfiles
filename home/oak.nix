{ lib, config, pkgs, ... }: {
  imports = [
    ./age.nix
    ./audio.nix
    ./cli
    ./desktop
    ./dev
    ./veecle
    ./wluma.nix
    ./xdg.nix
  ];

  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    iamb
    wluma
  ];

  xdg.configFile = {
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
