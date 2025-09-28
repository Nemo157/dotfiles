{ lib, pkgs, config, ... }:
let
  setup-xdg-cargo-home = pkgs.writeShellApplication {
    name = "setup-xdg-cargo-home";
    runtimeInputs = [pkgs.coreutils];
    text = lib.readFile ./setup-xdg-cargo-home.sh;
  };
in {
  home.sessionVariables = {
    CARGO_HOME = "$XDG_RUNTIME_DIR/cargo-home";
  };

  systemd.user = {
    sessionVariables = {
      CARGO_HOME = "$XDG_RUNTIME_DIR/cargo-home";
    };

    services ={
      setup-xdg-cargo-home = {
        Service = {
          ExecStart = lib.getExe setup-xdg-cargo-home;
          Type = "oneshot";
          RemainAfterExit = true;
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
  };

  xdg.configFile."cargo/config.toml".text = ''
    [build]
    target = "x86_64-unknown-linux-gnu"
    target-dir = "${config.xdg.cacheHome}/cargo/target/shared"

    [profile.release]
    lto = "thin"
    overflow-checks = true
    debug-assertions = true

    [profile.dev.package."*"]
    opt-level = 2
    debug = "line-tables-only"

    [profile.tarpaulin]
    inherits = "dev"

    [profile.tarpaulin.package."*"]
    opt-level = 0
    debug = "full"

    # `cargo-expand` pretends it's a builtin subcommand and reuses cargo's config file 👿.
    [expand]
    # This is a custom theme setup from `../../cli/bat/default.nix` that uses only ansi color codes
    # and reduces candy vomit.
    theme = "eink2"
  '';

  xdg.configFile."cargo-audit/audit.toml".text = ''
    # smh cargo-audit, get your own dirs, stop borrowing cargo's
    [database]
    path = "${config.xdg.cacheHome}/cargo-audit/advisory-db"
    fetch = false
    stale = false
  '';

  programs.git.ignores = [
    ".cargo/"
  ];
}
