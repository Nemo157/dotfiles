{ pkgs, ... }: {
  imports = [
    ./freetube.nix
    ./music
  ];

  home.packages = with pkgs; [
    dosbox-staging
  ];
}
