{ lib, config, pkgs, pkgs-unstable, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      eww-wayland = pkgs-unstable.eww-wayland.overrideAttrs (final: prev: rec {
        version = "tray-3-dynamic-icons";
        src = pkgs.fetchFromGitHub {
          owner = "ralismark";
          repo = "eww";
          rev = "2bfd3af0c0672448856d4bd778042a2ec28a7ca7";
          hash = "sha256-t62kQiRhzTL5YO6p0+dsfLdQoK6ONjN47VKTl9axWl4=";
        };
        cargoDeps = prev.cargoDeps.overrideAttrs (lib.const {
          name = "eww-${version}-vendor.tar.gz";
          inherit src;
          outputHash = "sha256-fUTNlAvhfgqrro+4uKyTwQPtoru9AnBHmy0XcOMUfOI=";
        });
        buildInputs = prev.buildInputs ++ [
          pkgs.libdbusmenu-gtk3
        ];
      });
    })
  ];

  xdg.dataFile."eww/no-album.png" = {
    source = pkgs.requireFile {
      name = "Generic-icon.png";
      url = "https://icons.iconarchive.com/icons/musett/cds/256/Generic-icon.png";
      sha256 = "CoOMVEYnZPTBAZcpD7N0XA5z4yNfOCe5EGBMF7zcViY=";
    };
  };

  programs.eww = {
    enable = true;
    package = pkgs.eww-wayland;
    configDir = ./eww;
  };

  xdg.dataFile."light-mode.d/eww-light.sh" = {
    source = pkgs.writeShellScript "eww-light.sh" ''
      ${pkgs-unstable.eww-wayland}/bin/eww update color-scheme=light
    '';
  };

  xdg.dataFile."dark-mode.d/eww-dark.sh" = {
    source = pkgs.writeShellScript "eww-dark.sh" ''
      ${pkgs-unstable.eww-wayland}/bin/eww update color-scheme=dark
    '';
  };


  scripts."eww-hypr-workspaces" = {
    runtimeInputs = [ pkgs.hyprland pkgs.socat pkgs.jq ];
    text = ''
      spaces() {
        AWS=$(hyprctl activeworkspace -j | jq '.id')
        AWI=$(hyprctl activewindow -j | jq -r '.address')
        export AWS AWI
        {
          echo '[
            {"workspace":{"id":1,"name":"einz"}},
            {"workspace":{"id":2,"name":"zwei"}},
            {"workspace":{"id":3,"name":"drei"}},
            {"workspace":{"id":4,"name":"vier"}}
          ]'
          hyprctl clients -j
        } | jq -sMc '
              [
                flatten
                | group_by(.workspace.id)
                | .[]
                | .[0].workspace + {
                    windows: [
                      .[]
                      | select(.address)
                      | {
                        class,
                        title,
                        active: (.address == env.AWI),
                      }
                    ]
                  }
                | . + {
                    active: (.id | tostring == env.AWS),
                  }
              ]
            '
      }

      spaces
      SOCKET="UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
      socat -u "$SOCKET" - | while read -r; do
        spaces
        # Some events like closing windows fire before everything is updated,
        # check again after a little while :ferrisPensive:
        sleep 0.1
        spaces
      done
    '';
  };
}
