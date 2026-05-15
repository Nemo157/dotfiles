# New machine setup: run `atuin key` on an existing machine, then
# `atuin login` on the new machine with blank user/pass and that key.
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
