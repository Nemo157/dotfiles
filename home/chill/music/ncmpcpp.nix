{ lib, config, pkgs, ... }: {
  programs.ncmpcpp = {
    enable = true;
    bindings = [
      { key = "k"; command = "scroll_up"; }
      { key = "j"; command = "scroll_down"; }
      { key = "d"; command = "delete_playlist_items"; }
    ];
  };
}
