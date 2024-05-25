{ ts, ... }: {
  programs.atuin = {
    settings = {
      sync_address = "http://${ts.hosts.mithril.host}:8888";
      daemon = {
        sync_frequency = 30;
      };
    };
  };
}
