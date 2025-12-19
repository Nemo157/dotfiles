{ pkgs, ... }: {
  home.packages = [ pkgs.slack ];

  services.dunst.settings.slack = {
    desktop_entry = "Slack";
    new_icon = "${pkgs.slack}/share/pixmaps/slack.png";
  };
}
