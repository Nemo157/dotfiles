{ config, ... }: {
  xdg.configFile."cargo/config.toml".text = ''
    [build]
    target = "x86_64-unknown-linux-gnu"

    [profile.release]
    lto = "thin"
    overflow-checks = true
    debug-assertions = true

    [profile.dev.package."*"]
    opt-level = 2
    debug = "line-tables-only"
  '';

  xdg.configFile."cargo-audit/config.toml".text = ''
    # smh cargo-audit, get your own dirs, stop borrowing cargo's
    [database]
    path = "${config.xdg.cacheHome}/cargo-audit/advisory-db"
    fetch = false
    stale = false
  '';
}
