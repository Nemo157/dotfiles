{ config, lib, pkgs, ... }:
let
  configDir = "${config.xdg.configHome}/pi";
  stateDir = "${config.xdg.stateHome}/pi";

  pi-coding-agent = pkgs.unstable.pi-coding-agent;

  extensions = {
    pi-permission-system = pkgs.callPackage ./extensions/pi-permission-system { };
  };

  pi-wrapped = pkgs.symlinkJoin {
    pname = "pi-coding-agent-wrapped";
    version = pi-coding-agent.version;
    paths = [ pi-coding-agent ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in $out/bin/*; do
        wrapProgram "$bin" \
          --set-default PI_CODING_AGENT_DIR "${configDir}" \
          --set-default PI_SKIP_VERSION_CHECK 1 \
          --set-default PI_OFFLINE 1
      done
    '';
  };
in
{
  home.packages = [ pi-wrapped ];

  xdg.configFile = {
    "pi/settings.json".text = builtins.toJSON {
      defaultProvider = "anthropic";
      defaultModel = "claude-opus-4-7";
      defaultThinkingLevel = "medium";

      quietStartup = true;
      enableInstallTelemetry = false;

      packages = [
        "${extensions.pi-permission-system.packageRoot}"
      ];

      extensions = [
        "${./extensions/cli-tools}/index.ts"
      ];
    };

    "pi/extensions/pi-permission-system/config.json".text = builtins.toJSON {
      permission = {
        "*" = "ask";

        path = {
          "*" = "allow";
          "*.env" = "deny";
          "*.env.*" = "deny";
          "*.env.example" = "allow";
          "**/.ssh/**" = "deny";
          "**/.gnupg/**" = "deny";
          "**/.age/**" = "deny";
          "**/*.age" = "deny";
        };

        read = "allow";
        ls = "allow";
        grep = "allow";
        glob = "allow";

        write = "ask";
        edit = "ask";

        # No direct bash access, instead specific local tools registered by the cli-tools extension
        bash = "deny";

        # Read-only CLI wrappers from ./extensions/cli-tools.
        jj-status = "allow";
        jj-diff = "allow";
        jj-log = "allow";
        git-status = "allow";
        git-diff = "allow";
        git-log = "allow";
        rg = "allow";
        fd = "allow";

        external_directory = "ask";
      };
    };

    "pi/auth.json".source = config.lib.file.mkOutOfStoreSymlink "${stateDir}/auth.json";
    "pi/sessions".source = config.lib.file.mkOutOfStoreSymlink "${stateDir}/sessions";
  };

  # Ensure the state dir exists before pi first tries to write auth.json / sessions into it.
  home.activation.piStateDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg "${stateDir}/sessions"}
  '';
}
