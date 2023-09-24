{ ... }: {
  imports = [
    ./alacritty.nix
    ./firefox.nix
    ./foot.nix
    ./fonts.nix
    ./i3.nix
    ./sway.nix
  ];

  home.keyboard = {
      layout = "us";
      variant = "dvp";
      options = [ "caps:escape" "compose:ralt" ];
  };
}
