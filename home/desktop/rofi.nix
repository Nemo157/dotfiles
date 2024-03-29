{ lib, config, pkgs, ... }: {
  programs.rofi = {
    enable = true;
    extraConfig = {
      modi = "drun,window,run,emoji:rofimoji";
      show-icons = true;
      run-command = "bash -c 'cmd=({cmd}); app=\$(systemd-escape \"\$cmd\"); systemd-run --scope --user --unit=app-rofi-\$app-\$RANDOM systemd-cat -t \$app {cmd}'";
      kb-element-next = "";
      kb-element-prev = "";
      kb-mode-next = "Shift+Right,Tab";
      kb-mode-previous = "Shift+Left";
      kb-row-up = "Up,Control+p";
      kb-row-tab = "";
    };
  };
  home.packages = [ pkgs.rofimoji ];
}
