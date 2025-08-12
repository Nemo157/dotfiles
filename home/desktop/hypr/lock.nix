{ lib, config, pkgs, ... }:
let
  sol = import ../../sol.nix;

  hyprlock-date-time = pkgs.writeShellApplication {
    name = "hyprlock-date-time";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      date +'%Y<span color="${sol.hash.base02}">-</span>%m<span color="${sol.hash.base02}">-</span>%d'
      if (( 10#$(date +'%S') % 2 ))
      then
        date +'%H<span color="${sol.hash.base02}">:</span>%M<span color="${sol.hash.base02}">%z</span>'
      else
        date +'%H %M<span color="${sol.hash.base02}">%z</span>'
      fi | tr -d $'\n'
    '';
  };
in {
  home.packages = with pkgs; [ hyprlock ];

  xdg.configFile."hypr/hyprlock.conf".text = ''
    general {
      ignore_empty_input = true
    }

    background {
      monitor =
      color = ${sol.rgb.base03}
    }

    input-field {
      monitor =
      size = 1600, 80
      outline_thickness = 0
      dots_size = 1.0
      dots_spacing = 0.0
      dots_center = true
      dots_rounding = 0
      inner_color = ${sol.rgb.base02}
      font_color = ${sol.rgb.base01}
      fade_on_empty = false
      placeholder_text =
      hide_input = false
      rounding = 0
      check_color = ${sol.rgb.base03}
      fail_color = ${sol.rgb.red}
      fail_text = ☠️
      fail_transition = 300
      swap_font_color = true

      halign = center
      valign = center
    }

    label {
      monitor =
      text = cmd[update:1000] ${lib.getExe hyprlock-date-time}
      text_align = left
      color = ${sol.rgb.base01}
      font_family = FiraCode Nerd Font
      font_size = 25

      halign = left
      valign = bottom
    }

    label {
      monitor =
      text = $LAYOUT
      text_align = right
      color = ${sol.rgb.base02}
      font_family = FiraCode Nerd Font
      font_size = 25

      halign = center
      valign = bottom
    }
  '';
}
