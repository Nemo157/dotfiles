{
  description = "Home Manager configuration of nemo157";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";

    nixpkgs-unstable.url = "github:nixos/nixpkgs";

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.lib-aggregate.follows = "lib-aggregate";
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

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    # transitive dependencies to allow following :ferrisPensive:
    flake-utils.url = "github:numtide/flake-utils";
    lib-aggregate = {
      url = "github:nix-community/lib-aggregate";
      inputs.flake-utils.follows = "flake-utils";
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
    rust-overlay,
    ...
  }: let
    system = "x86_64-linux";
    pkgs-unstable = import nixpkgs-unstable { inherit system; };
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        self.overlays.default
        rust-overlay.overlays.default
      ];
    };
    pkgs-wayland = nixpkgs-wayland.packages.${system};
    nur = import nixur { inherit pkgs; nurpkgs = pkgs; };
  in rec {

    maintainers = {
      nemo157 = {
        email = "nix@nemo157.com";
        name = "Nemo157";
        github = "Nemo157";
        githubId = 81079;
        keys = [{
          fingerprint = "E3D8 2B6B F270 2722 4925  CD19 A65D C69A 2364 9F86";
        }];
      };
    };

    overlays.default = import ./overlays { inherit pkgs-unstable maintainers; };

    packages."${system}" = import ./packages { inherit pkgs; };

    nixosConfigurations = {
      mithril = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./nixos/mithril
        ];
      };
    };

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
