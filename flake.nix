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

    u2f-touch-detector = {
      url = "github:Nemo157/u2f-touch-detector";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.home-manager.follows = "home-manager";
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
    u2f-touch-detector,
    ...
  }: let
    system = "x86_64-linux";

    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        agenix.overlays.default
        nixseparatedebuginfod.overlays.default
        nixur.overlay
        rust-overlay.overlays.default
        u2f-touch-detector.overlays.default
        self.overlays.default
      ];
    };

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
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          nixseparatedebuginfod.nixosModules.default
          pin-nixpkgs
          ./nixos/common
        ];

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          sharedModules = [
            agenix.homeManagerModules.default
            u2f-touch-detector.homeManagerModules.default
            ./home/scripts.nix
          ];
        };
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
          buildOnTarget = true;
        };
        home-manager = {
          extraSpecialArgs = {
            ts = ts // { self = ts.hosts.mithril; };
          };
          users.nemo157 = {
            imports = [
              ./home/nemo157.nix
              ./home/mithril.nix
            ];
          };
        };
      };

      zinc = {
        imports = [
          nixos-hardware.nixosModules.apple-t2
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-pc-ssd
          ./nixos/zinc
        ];
        deployment = {
          allowLocalDeployment = true;
        };
        home-manager = {
          extraSpecialArgs = {
            ts = ts // { self = ts.hosts.zinc; };
          };
          users.nemo157 = {
            imports = [
              ./home/nemo157.nix
              ./home/zinc.nix
            ];
          };
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
    legacyPackages.${system} = pkgs;

    devShells.${system} = import ./shells { inherit pkgs; };

    colmena = colmena-config;

    nixosConfigurations = {
      inherit (colmena-hive.nodes) contabo mithril zinc;
    };
  };
}
