{ config, ... }: {
  age = {
    identityPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519-agenix" ];
    # Needs to have $XDG_RUNTIME_DIR pre-resolved
    secretsDir = "/run/user/1000/agenix";
  };
}
