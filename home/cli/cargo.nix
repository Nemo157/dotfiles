{
  xdg.configFile."cargo/config.toml".text = ''
    [profile.release]
    lto = "thin"
    overflow-checks = true
    debug-assertions = true

    [profile.dev.package."*"]
    opt-level = 2
    debug = "line-tables-only"
  '';
}
