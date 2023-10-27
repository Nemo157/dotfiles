{ pkgs, ... }: {
  imports = [
    ./music
  ];

  home.packages = with pkgs; [
    dosbox-staging
    freetube
  ];
}
