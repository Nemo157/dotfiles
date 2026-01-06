{ pkgs, ... }: {
  home.packages = [
    pkgs.pavucontrol
  ];

  xdg.configFile = {
    "wireplumber/wireplumber.conf.d/51-config.conf".text = ''
      wireplumber.settings = {
        node.features.audio.monitor-ports = false
      }

      monitor.alsa.rules = [
        # disable all alsa devices except usb mic
        # (seem to be different firmware that reports a different nick on my 2 devices)
        {
          matches = [
            { device.nick = "!~(Samson GoMic|Samson Go Mic)" }
          ]
          actions = { update-props = { device.disabled = true } }
        }

        # disable output on usb mic
        {
          matches = [
            { node.nick = "Samson GoMic", media.class = "Audio/Sink" }
            { node.nick = "Samson Go Mic", media.class = "Audio/Sink" }
          ]
          actions = { update-props = { node.disabled = true } }
        }

        # give more useful names to usb mics
        # (no serial numbers afaict, but we can abuse the different nicks they report)
        {
          matches = [
            { node.nick = "Samson Go Mic", media.class = "Audio/Source" }
          ]
          actions = { update-props = { node.description = "GoMic A" } }
        }
        {
          matches = [
            { node.nick = "Samson GoMic", media.class = "Audio/Source" }
          ]
          actions = { update-props = { node.description = "GoMic B" } }
        }
      ]

      # disable input on bluetooth devices so they stay with higher quality output
      monitor.bluez.rules = [
        {
          matches = [
            { device.description = "WH-1000XM3" }
            { device.description = "J55" }
          ]
          actions = {
            update-props = {
              media-role.use-headset-profile = false
              bluetooth.autoswitch-to-headset-profile = false
              bluez5.autoswitch-profile = false

              bluez5.auto-connect = [ a2dp_sink ]
            }
          }
        }
      ]

      monitor.bluez.properties = {
        bluez5.roles = [ a2dp_source a2dp_sink ]
        bluez5.hfphsp-backend = "none"
      }
    '';

    "pipewire/pipewire.conf.d/92-low-latency.conf".text = ''
      context.properties = {
        default.clock.rate = 48000
        default.clock.quantum = 256
        default.clock.min-quantum = 256
        default.clock.max-quantum = 256
      }
    '';
  };
}
