{ pkgs, ... }: {
  imports = [
    ./freetube.nix
    ./sunshine.nix
    ./shairport-sync.nix
    ./music
  ];

  home.packages = with pkgs; [
    dosbox-staging
  ];
}
