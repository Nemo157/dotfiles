{ pkgs, ... }: {
  imports = [
    ./music
  ];

  home.packages = with pkgs; [
    dosbox-staging
    freetube
    bs-manager # BeatSaber Mod Manager
  ];
}
