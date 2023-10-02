{ pkgs, ... }:
let
  sol = import ../../sol.nix;
in {
  programs = {
    gh = {
      enable = true;
      extensions = with pkgs; [ gh-dash gh-poi ];
      settings = {
        prompt = "enabled";
        aliases = {
          co = "pr checkout --detach";
        };
      };
    };
  };
}
