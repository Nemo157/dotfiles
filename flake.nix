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
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.25.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    agenix,
    home-manager,
    hyprland,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-wayland,
    nixur,
  }: let
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
          ./home/scripts.nix
          ./home/nemo157.nix
          ./home/mithril.nix
          hyprland.homeManagerModules.default
          agenix.homeManagerModules.default
        ];
      };
    };
  };
}
