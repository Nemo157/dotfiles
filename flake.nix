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
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:nixos/nixos-hardware";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

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

    # > nix flake update ἐννεάς
    # error: invalid flake input attribute path element 'ἐννεάς'
    # :pensive:
    ennead = {
      url = "github:Nemo157/ennead";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.home-manager.follows = "home-manager";
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

    audio-cpp = {
      url = "github:0xShug0/audio.cpp/80ef3879f1d4ec29888e7a69782caa80fd6cf195";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yt-dlp-src = { url = "github:yt-dlp/yt-dlp"; flake = false; };

    nixpkgs-xr = {
      url = "github:nix-community/nixpkgs-xr";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.flake-compat.follows = "flake-compat";
      inputs.systems.follows = "systems";
    };
  };

  outputs = inputs @ {
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
    ennead,
    flake-utils,
    audio-cpp,
    nixpkgs-xr,
    ...
  }: flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-darwin"] (system: let
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "python3.13-beets-2.5.1" # It's got a CVE in the webui which I don't use.
        ];
      };
      overlays = [
        (final: prev: {
          unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              (final: prev: {
                pi-coding-agent = prev.pi-coding-agent.overrideAttrs rec {
                  version = "0.87.1";

                  src = final.fetchFromGitHub {
                    owner = "earendil-works";
                    repo = "pi";
                    tag = "v${version}";
                    hash = "sha256-GUhlq6t+l6iiViOZ0bkV28v3ZDqcLvEwpZpYZ5JAyDk=";
                  };

                  npmDeps = final.fetchNpmDeps {
                    inherit src;
                    name = "${final.pi-coding-agent.name}-npm-deps";
                    hash = "sha256-JBIYoP2vvRNz1HONNvDJ1U3c+nmCJ7/VgNthRTkrkIA=";
                  };

                  modelData = final.fetchurl {
                    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${final.pi-coding-agent.version}.tgz";
                    hash = "sha256-NbRDLyfMJmX4a+67mvajmxJRlwiDwwRL2L5PToxzHKA=";
                  };
                };
              })

              (final: prev: {
                nodejs-slim_26 = prev.nodejs-slim_26.overrideAttrs (_old: { doCheck = false; });
              })
            ];
          };
          home-manager = home-manager.packages.${system}.home-manager;
          audio-cpp = audio-cpp.packages.${system};
        })
        agenix.overlays.default
        colmena.overlays.default
        nixur.overlays.default
        rust-overlay.overlays.default
        u2f-touch-detector.overlays.default
        appearance-watcher.overlays.default
        ferris-icons.overlays.default
        nixpkgs-xr.overlays.default
        self.overlays.default
        # run into various issues (e.g. nix-serve)
        # lix-module.overlays.lixFromNixpkgs
      ];
    };

    prefixAttrs = prefix: attrs:
      nixpkgs.lib.mapAttrs'
        (name: value: { name = "${prefix}-${name}"; inherit value; })
        attrs;

  in {
    packages = import ./packages { inherit pkgs; };
    legacyPackages = pkgs;

    devShells = import ./shells { inherit pkgs; } // {
      local = pkgs.mkShell {
        buildInputs = [
          pkgs.agenix
        ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
          pkgs.home-manager
        ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
          pkgs.colmena
        ];
      };
    };

    checks =
      (prefixAttrs "packages" self.outputs.packages.${system})
      // (prefixAttrs "shells" self.outputs.devShells.${system})
      // (prefixAttrs "colmena" (nixpkgs.lib.mapAttrs
           (name: node: node.config.system.build.toplevel)
           (nixpkgs.lib.filterAttrs
             (name: node: node.pkgs.stdenv.hostPlatform.system == system)
             self.outputs.colmenaHive.nodes)));
  }) // (let
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

    # adds all inputs (recursively) as extra dependencies so they will be gc-rooted
    root-flake-inputs = let
      collectFlakeInputs = input:
        [ input ]
        ++ builtins.concatMap collectFlakeInputs (builtins.attrValues (input.inputs or { }));
    in {
      system.extraDependencies =
        [ self ]
        ++ builtins.concatMap collectFlakeInputs (builtins.attrValues inputs);
    };

    ts = rec {
      domain = "emerald-koi.ts.net";
      ips = {
        contabo = "100.93.46.63";
        mithril = "100.120.211.104";
        zinc = "100.71.97.27";
        slate = "100.104.56.100";
      };
      hosts = nixpkgs.lib.mapAttrs (host: ip: {
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

    overlays.default = import ./overlays { inherit (self.outputs) maintainers; inherit inputs; };

    homeManagerModules.default = import ./modules/home-manager;

    homeConfigurations = {
      "nemo157@lime" = home-manager.lib.homeManagerConfiguration {
        pkgs = self.outputs.legacyPackages."aarch64-darwin";

        extraSpecialArgs = {
          inherit nix-colors ts syncthing;
        };

        modules = [
          agenix.homeManagerModules.default
          u2f-touch-detector.homeManagerModules.default
          self.homeManagerModules.default
          ennead.homeManagerModules.default
          ./home/lime.nix
        ];
      };
    };

    colmena = {
      meta = {
        nixpkgs = self.outputs.legacyPackages."x86_64-linux";
        specialArgs = {
          inherit ts syncthing;
          nixos-hardware = nixos-hardware.nixosModules;
        };
      };

      defaults = {
        imports = [
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          pin-nixpkgs
          ./nixos/common
          ennead.nixosModules.default
        ];

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          sharedModules = [
            agenix.homeManagerModules.default
            u2f-touch-detector.homeManagerModules.default
            self.homeManagerModules.default
            ennead.homeManagerModules.default
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
          root-flake-inputs
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
        system.extraDependencies = [
          self.devShells."x86_64-linux".rust
          self.devShells."x86_64-linux".rust-unwrapped
        ];
      };

      zinc = {
        imports = [
          ./nixos/zinc
          root-flake-inputs
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
        system.extraDependencies = [
          self.devShells."x86_64-linux".rust
          self.devShells."x86_64-linux".rust-unwrapped
        ];
      };

      oak = {
        imports = [
          ./nixos/oak
          root-flake-inputs
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
        system.extraDependencies = [
          self.devShells."x86_64-linux".rust
          self.devShells."x86_64-linux".rust-unwrapped
        ];
      };
    };

    colmenaHive = colmena.lib.makeHive self.outputs.colmena;

    nixosConfigurations = {
      inherit (self.outputs.colmenaHive.nodes) contabo mithril zinc oak;
    };

  });
}
