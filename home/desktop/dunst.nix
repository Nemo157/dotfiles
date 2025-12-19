{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        width = "(500,500)";
        height = "(200,200)";
        offset = "(20,20)";
        origin = "top-right";
        transparency = 10;
        font = "FiraCode Nerd Font 14";
        vertical_alignment = "top";

        min_icon_size = 184;
        max_icon_size = 184;
        text_icon_padding = 8;

        show_indicators = false;
      };

      urgency_normal = {
        timeout = 10;
      };
    };
  };
}
