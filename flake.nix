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
      inputs.flake-compat.follows = "flake-compat";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:nixos/nixos-hardware";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    nixpkgs-unstable.url = "github:nixos/nixpkgs";

    nixur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/release-2.93.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    u2f-touch-detector = {
      url = "github:Nemo157/u2f-touch-detector/monitor";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.home-manager.follows = "home-manager";
    };

    appearance-watcher = {
      url = "github:Nemo157/appearance-watcher";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    ferris-icons = {
      url = "github:Nemo157/ferris-icons";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    tangled = {
      url = "git+https://tangled.org/@tangled.org/core";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.flake-compat.follows = "flake-compat";
      inputs.gomod2nix.follows = "gomod2nix";
    };

    # transitive dependencies to allow following :ferrisPensive:
    systems.url = "github:nix-systems/default-linux";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = {
    self,
    agenix,
    appearance-watcher,
    colmena,
    ferris-icons,
    home-manager,
    lix-module,
    nix-colors,
    nixos-hardware,
    nixpkgs,
    nixpkgs-unstable,
    nixur,
    rust-overlay,
    u2f-touch-detector,
    tangled,
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
        colmena.overlays.default
        nixur.overlays.default
        rust-overlay.overlays.default
        u2f-touch-detector.overlays.default
        appearance-watcher.overlays.default
        ferris-icons.overlays.default
        self.overlays.default
        lix-module.overlays.lixFromNixpkgs
      ];
    };

    # pin nixpkgs to system nixpkgs for determinism
    pin-nixpkgs = {
      nix = {
        # For flake commands
        registry = {
          # In case I want to access stuff pre-overlay
          nixpkgs.flake = nixpkgs;

          nixpkgs-unstable.flake = nixpkgs-unstable;

          # Uses the `legacyPackages` below to allow access to my overlays,
          # along with my packages through `packages` like normal
          pkgs.flake = self;
        };

        # For legacy commands
        channel.enable = true;
        nixPath = [
          "nixpkgs=${nixpkgs.outPath}"
          "nixpkgs-unstable=${nixpkgs-unstable.outPath}"
        ];

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

    syncthing = {
      Slabish = "OSSG4UZ-FX5FJIW-K4FXLTD-IA5HWNI-TJXV6RT-64JTYCU-IUXET5R-TWZZLAS";
      StuffnesslyTri = "AURMWFA-RXS5I5F-KP5QKUB-ZVGDZEY-BTOZEYN-FNOTVDB-LK7PDAE-PVAW6QH";
      StuffnesslyZwei = "XCINWZR-MPBT3KM-M5VKVBD-BAN56G2-VZNYE6N-OJJYUKK-2H3WWMP-55LMYQY";
      contabo = "FPWUA22-RTUZ7KO-K23E642-EFXWH6P-VSBGMKF-XWLVOO2-LVEHO7M-3VIGKQZ";
      mithril = "UAFMSLM-HVNJUCK-JBSKBXZ-TMCCCYR-GUMDNID-IXBXETE-C2SUN6W-KDI4HQN";
      zinc = "4OZ4P7V-7PTKETZ-NG4DVX7-5VABDM7-BY2XMW3-2PFOQV7-FRZCABK-VXA4PAT";
    };

    prefixAttrs = prefix: attrs:
      pkgs.lib.mapAttrs'
        (name: value: { name = "${prefix}-${name}"; inherit value; })
        attrs;

  in {

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

    overlays.default = import ./overlays { inherit pkgs-unstable; inherit (self.outputs) maintainers; };

    packages.${system} = import ./packages { inherit pkgs; };
    legacyPackages.${system} = pkgs;

    homeManagerModules.default = import ./modules/home-manager;

    devShells.${system} = import ./shells { inherit pkgs; } // {
      local = pkgs.mkShell {
        buildInputs = [
          pkgs.agenix
          pkgs.colmena
        ];
      };
    };

    colmena = {
      meta = {
        nixpkgs = pkgs;
        specialArgs = {
          inherit ts syncthing;
          nixos-hardware = nixos-hardware.nixosModules;
        };
      };

      defaults = {
        imports = [
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          tangled.nixosModules.knot
          pin-nixpkgs
          ./nixos/common
        ];

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          sharedModules = [
            agenix.homeManagerModules.default
            u2f-touch-detector.homeManagerModules.default
            self.homeManagerModules.default
          ];
          extraSpecialArgs = {
            inherit nix-colors;
          };
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

      oak = {
        imports = [
          ./nixos/oak
        ];
        deployment = {
          allowLocalDeployment = true;
        };
        home-manager = {
          users.wim = {
            imports = [
              ./home/oak.nix
            ];
            home = { username = "wim"; homeDirectory = "/home/wim"; };
          };
        };
      };
    };

    colmenaHive = colmena.lib.makeHive self.outputs.colmena;

    nixosConfigurations = {
      inherit (self.outputs.colmenaHive.nodes) contabo mithril zinc oak;
    };

    checks.${system} =
      (prefixAttrs "packages" self.outputs.packages.${system})
      // (prefixAttrs "shells" self.outputs.devShells.${system});
  };
}
