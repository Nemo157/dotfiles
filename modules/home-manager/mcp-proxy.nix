{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mcp-proxy;
  json = pkgs.formats.json {};

  enabledServers = filterAttrs (_: s: s.enable) cfg.servers;

  serverConfig = mapAttrs (_: s: {
    command = head s.command;
    args = tail s.command;
    env = s.env;
  }) enabledServers;

  configFile = json.generate "mcp-proxy-servers.json" { mcpServers = serverConfig; };

  serverType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable this server.";
      };

      command = mkOption {
        type = types.listOf types.str;
        description = "Command and arguments to launch the MCP server.";
        example = [ "npx" "-y" "@cocal/google-calendar-mcp" ];
      };

      env = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Environment variables passed to the server.";
      };
    };
  };
in {
  options.services.mcp-proxy = {
    enable = mkEnableOption "mcp-proxy SSE gateway";

    package = mkOption {
      type = types.package;
      default = pkgs.mcp-proxy;
      description = "The mcp-proxy package to use.";
    };

    port = mkOption {
      type = types.port;
      default = 3001;
      description = "Port for the mcp-proxy HTTP server.";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Hostname for the mcp-proxy HTTP server.";
    };

    path = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Extra packages to add to the service PATH (e.g. nodejs for npx).";
    };

    servers = mkOption {
      type = types.attrsOf serverType;
      default = {};
      description = "Named MCP servers to proxy.";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.mcp-proxy = {
      Unit = {
        Description = "mcp-proxy SSE gateway";
        After = [ "network.target" ];
        X-Restart-Triggers = [ "${configFile}" ];
      };

      Service = let
        execStart = "${lib.getExe cfg.package} --host ${cfg.hostname} --port ${toString cfg.port} --named-server-config ${configFile}";
      in {
        ExecStart =
          if cfg.path == [] then execStart
          else "${pkgs.writeShellScript "mcp-proxy-start" ''
            export PATH="${lib.makeBinPath cfg.path}:$PATH"
            exec ${execStart}
          ''}";
        Restart = "on-failure";
        RestartSteps = 5;
        RestartMaxDelaySec = 10;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
