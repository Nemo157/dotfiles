{
  description = "Home Manager configuration of nemo157";

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.home-manager.follows = "home-manager";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.stable.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:nixos/nixos-hardware";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

    nixpkgs-unstable.url = "github:nixos/nixpkgs";

    nixur.url = "github:nix-community/NUR";

    nixseparatedebuginfod = {
      url = "github:symphorien/nixseparatedebuginfod";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    # transitive dependencies to allow following :ferrisPensive:
    systems.url = "github:nix-systems/default-linux";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };

  outputs = {
    self,
    agenix,
    colmena,
    home-manager,
    nixos-hardware,
    nixpkgs,
    nixpkgs-unstable,
    nixur,
    nixseparatedebuginfod,
    rust-overlay,
    ...
  }: let
    system = "x86_64-linux";

    pkgs-unstable = import nixpkgs-unstable { inherit system; };

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        agenix.overlays.default
        nixseparatedebuginfod.overlays.default
        rust-overlay.overlays.default
        self.overlays.default
      ];
    };

    nur = import nixur { inherit pkgs; nurpkgs = pkgs; };

    # pin nixpkgs to system nixpkgs for determinism
    pin-nixpkgs = {
      nix = {
        # For flake commands
        registry = {
          # In case I want to access stuff pre-overlay
          nixpkgs.flake = nixpkgs;

          # Uses the `legacyPackages` below to allow access to my overlays,
          # along with my packages through `packages` like normal
          pkgs.flake = self;
        };

        # For legacy commands
        channel.enable = true;
        nixPath = [ "nixpkgs=${nixpkgs.outPath}" ];

        # Don't import all the registry entries, just explicit ones above
        settings.flake-registry = "/etc/nixos/registry.json";
      };
    };

    ts = rec {
      domain = "emerald-koi.ts.net";
      ips = {
        contabo = "100.93.46.63";
        mithril = "100.120.211.104";
        zinc = "100.71.97.27";
      };
      hosts = pkgs.lib.mapAttrs (host: ip: {
        inherit ip;
        host = "${host}.${domain}";
      }) ips;
    };

    colmena-config = {
      meta = {
        nixpkgs = pkgs;
        specialArgs = {
          inherit ts;
        };
      };

      defaults = {
        imports = [
          pin-nixpkgs
          nixseparatedebuginfod.nixosModules.default
          agenix.nixosModules.default
          ./nixos/common
        ];
      };

      contabo = {
        imports = [
          ./nixos/contabo
        ];
      };

      mithril = {
        imports = [
          ./nixos/mithril
        ];
        deployment = {
          allowLocalDeployment = true;
        };
      };

    };

    colmena-hive = colmena.lib.makeHive colmena-config;

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

    packages.${system} = import ./packages { inherit pkgs; };
    legacyPackages.${system} = pkgs // { unstable = pkgs-unstable; };

    devShells.${system} = import ./shells { inherit pkgs; };

    colmena = colmena-config;

    nixosConfigurations = {
      inherit (colmena-hive.nodes) contabo mithril;

      zinc = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = {
          ts = ts // { self = ts.hosts.zinc; };
        };
        modules = [
          pin-nixpkgs
          nixos-hardware.nixosModules.apple-t2
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-pc-ssd
          agenix.nixosModules.default
          ./nixos/common
          ./nixos/zinc
        ];
      };
    };

    homeConfigurations = {
      "nemo157@mithril" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit pkgs-unstable nur;
          ts = ts // { self = ts.hosts.mithril; };
        };
        modules = [
          ./home/scripts.nix
          ./home/nemo157.nix
          ./home/mithril.nix
          agenix.homeManagerModules.default
        ];
      };

      "nemo157@zinc" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit pkgs-unstable nur;
          ts = ts // { self = ts.hosts.zinc; };
        };
        modules = [
          ./home/scripts.nix
          ./home/nemo157.nix
          ./home/zinc.nix
          agenix.homeManagerModules.default
        ];
      };
    };
  };
}
