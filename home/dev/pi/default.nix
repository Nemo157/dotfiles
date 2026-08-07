{ config, lib, pkgs, ... }:
let
  permissionSystemLogs =
    "${config.xdg.stateHome}/pi/extensions/pi-permission-system/logs";

  # Cache root for the web-fetch extension. Must stay in sync with the
  # extension's own default (XDG_CACHE_HOME/pi/web-fetch, see
  # extensions/web-fetch/config.ts); it is passed to the extension explicitly
  # and granted read access via piInfrastructureReadPaths below.
  webFetchCacheDir = "${config.xdg.cacheHome}/pi/web-fetch";

  # Cargo stores dependency source under CARGO_HOME (relocated to
  # $XDG_RUNTIME_DIR/cargo-home and symlinked to $XDG_RUNTIME_DIR/cargo by
  # home/dev/rust/cargo.nix): registry crates under registry/src and git deps
  # under git/checkouts. Allow read-only access so the cargo-dependency-path
  # tool's returned paths (and follow-up `read`s) don't trip an
  # external_directory prompt. Patterns cover both the CARGO_HOME symlink
  # alias and its resolved target; XDG_RUNTIME_DIR (`/run/user/<uid>`) is
  # matched with a wildcard since the uid isn't known at eval time.
  cargoSourceDirs = [
    "/run/user/*/cargo-home/registry/src"
    "/run/user/*/cargo-home/git/checkouts"
    "/run/user/*/cargo/registry/src"
    "/run/user/*/cargo/git/checkouts"
  ];
in
{
  xdg.configFile."pi/extensions/pi-permission-system/logs".source =
    config.lib.file.mkOutOfStoreSymlink permissionSystemLogs;

  # Global MCP server config read by the pi-mcp-adapter extension
  # (~/.config/mcp/mcp.json is its user-global shared source).
  xdg.configFile."mcp/mcp.json".text = builtins.toJSON {
    mcpServers = {
      # Exa remote MCP. No API key for now; add one later via e.g.
      # url = "https://mcp.exa.ai/mcp?exaApiKey=..."; (agenix secret).
      exa = {
        url = "https://mcp.exa.ai/mcp";
        # Register the web search tool as a first-class Pi tool instead of
        # only exposing it through the mcp proxy. Uses the original MCP
        # tool name (unprefixed).
        directTools = [ "web_search_exa" ];
      };
    };
  };

  home.activation.piPermissionSystemLogs =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArg permissionSystemLogs}
    '';

  programs.pi = {
    enable = true;
    package = pkgs.unstable.pi-coding-agent;

    settings = {
      quietStartup = true;
      enableInstallTelemetry = false;

      theme = "base24-ansi";
      themes = [ "${./themes}" ];

      compaction = {
        enabled = false;
      };

      packages = [
        (pkgs.callPackage ./extensions/pi-permission-system { }).packageRoot
        (pkgs.callPackage ./extensions/web-fetch { }).packageRoot
        (pkgs.callPackage ./extensions/pi-mcp-adapter { }).packageRoot
        # Source tree is the package root (no build step, no node_modules).
        "${pkgs.callPackage ./extensions/pine-of-glass { }}"
      ];

      extensions = [
        "${./extensions/cli-tools}/index.ts"
        "${./extensions/file-tools}/index.ts"
        "${./extensions/file-upload}/index.ts"
        "${./extensions/edit-toggle}/index.ts"
        "${./extensions/cache-ttl}/index.ts"
        "${./extensions/local-agents}/index.ts"
        "${./extensions/system-details}/index.ts"
        "${./extensions/continue-turn}/index.ts"
      ];
    };

    appendSystem = ''

      ## Pi Setup Notes

      You do not have direct bash/shell access in this pi setup. The `bash`
      tool is denied; instead, a curated set of local CLI wrappers is exposed
      as individual tools (e.g. `read`, `edit`, `write`, `rg`, `fd`,
      `mv`, `rm`, `cp`, `mkdir`, plus version-control wrappers).

      Which tools exist depends on the environment: the version-control
      wrappers are either the `jj-*` set (in a jj workspace, including
      colocated repos) or the `git-*` set (in a plain git repo), never both.
      Use whichever is listed in Available tools.

      If you need a command that isn't available as a registered tool, do not
      try to work around it or fabricate output. Stop and ask the user to add
      the missing tool to the `cli-tools` extension.
    '';

    extensionSettings.web-fetch = {
      cacheDir = webFetchCacheDir;
      # To enable the optional `prompt` parameter, set a small model here,
      # e.g. model = "anthropic/claude-haiku-4-5"; (there is no default).
    };

    extensionSettings.pi-permission-system = {
      # Live-authority chain: our local `edit-toggle` extension registers a
      # link with this name via registerAuthorizer. Naming it here is the
      # opt-in activation — without this entry the link would be inert.
      # See home/dev/pi/extensions/edit-toggle/index.ts.
      authorizerChain = [ "edit-toggle" ];

      # The web-fetch extension writes downloads / extractions / prompt
      # answers here and hands the agent cache paths to read. Auto-allow
      # read-only tools on that directory so those follow-up reads don't
      # trigger an external_directory approval prompt. (A dynamic per-path
      # grant is not possible: the live-authority chain downgrades any allow
      # on the external_directory/path surfaces to defer.)
      piInfrastructureReadPaths = [ webFetchCacheDir ];

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

        # Network egress via the web-fetch extension: gate each call.
        web-fetch = "ask";

        # Outbound file/data upload (exfiltration channel): always confirm.
        upload = "ask";

        # No direct bash access, instead specific local tools registered by the cli-tools extension
        bash = "deny";

        # Read-only CLI wrappers from ./extensions/cli-tools.
        jj-status = "allow";
        jj-diff = "allow";
        jj-log = "allow";
        jj-show = "allow";
        git-status = "allow";
        git-diff = "allow";
        git-log = "allow";
        # Read-only GitHub PR review view (network egress, but read-only).
        gh-pr-comments = "allow";
        rg = "allow";
        cargo-dependency-path = "allow";
        fd = "allow";
        nix-flake-info = "allow";
        nix-log = "allow";

        external_directory = {
          "*" = "ask";
        } // lib.listToAttrs (lib.concatMap (d: [
          {
            name = builtins.unsafeDiscardStringContext d;
            value = "allow";
          }
          {
            name = builtins.unsafeDiscardStringContext "${d}/*";
            value = "allow";
          }
        ]) (config.programs.pi.referenceDirs
          ++ [ config.programs.pi.referenceLinkDir ]
          ++ cargoSourceDirs));
      };
    };
  };
}
