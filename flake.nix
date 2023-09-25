{
  description = "Home Manager configuration of nemo157";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs";
    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixur.url = "github:nix-community/NUR";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, nixpkgs-wayland, nixur, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
      pkgs-unstable = import nixpkgs-unstable { inherit system; };
      pkgs-wayland = nixpkgs-wayland.packages.${system};
      nur = import nixur { inherit pkgs; nurpkgs = pkgs; };
    in {
      homeConfigurations = {
        "nemo157@mithril" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit pkgs-unstable pkgs-wayland nur;
          };
          modules = [
            ./home/nemo157.nix
            ./home/mithril.nix
          ];
        };
      };
    };
}
