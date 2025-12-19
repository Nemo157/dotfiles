{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        width = "(400,400)";
        height = "(200,200)";
        offset = "(84,20)";
        origin = "top-right";
        transparency = 10;
        font = "FiraCode Nerd Font 14";
        vertical_alignment = "top";
      };

      urgency_normal = {
        timeout = 10;
      };
    };
  };
}
