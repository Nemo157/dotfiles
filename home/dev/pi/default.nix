{ config, lib, pkgs, osConfig ? null, ... }:
let
  llamaSwapConfig = osConfig.services.llama-swap;

  llamaSwapModels = lib.attrNames (
    lib.filterAttrs
      (_: m: (m.capabilities.out or [ "text" ]) == [ "text" ])
      (if osConfig == null
        then { }
        else llamaSwapConfig.settings.models or { })
  );

  permissionSystemLogs =
    "${config.xdg.stateHome}/pi/extensions/pi-permission-system/logs";

  # Cache root for the web-fetch extension. Must stay in sync with the
  # extension's own default (XDG_CACHE_HOME/pi/web-fetch, see
  # extensions/web-fetch/config.ts); it is passed to the extension explicitly
  # and granted read access via piInfrastructureReadPaths below.
  webFetchCacheDir = "${config.xdg.cacheHome}/pi/web-fetch";

  # Output root for the cli-tools `tar` tool. Same contract as
  # webFetchCacheDir: kept in sync with the extension's own default
  # (XDG_CACHE_HOME/pi/tar, see extensions/cli-tools/config.ts), passed to the
  # extension explicitly, and granted read access below so the agent can read
  # or upload the archives it creates.
  tarCacheDir = "${config.xdg.cacheHome}/pi/tar";

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

  xdg.configFile."pi/models.json" = lib.mkIf (llamaSwapConfig.enable && llamaSwapModels != [ ]) {
    text = builtins.toJSON {
      providers.llama-swap = {
        name = "llama-swap (local)";
        baseUrl = "http://${llamaSwapConfig.listenAddress}:${toString llamaSwapConfig.port}/v1";
        api = "openai-completions";
        # Dummy key: llama-swap ignores auth, but pi hides models without one.
        apiKey = "llama-swap";
        models = map (id: { inherit id; contextWindow = 81920; reasoning = true; }) llamaSwapModels;
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

    # Drop the bash tool at the pi level, not just via `bash = "deny"` below.
    #
    # Prompt-cache stability: pi builds the base system prompt at startup from
    # the full tool set (bash bullet + bash's `promptGuidelines`). On the first
    # turn pi-permission-system's before_agent_start filters bash out of the
    # active set and rewrites the prompt — and its sanitizer additionally runs
    # `collapseExtraBlankLines` whenever it removed something. Pi then rebuilds
    # the base prompt from the narrowed tool set, so turn 2 sends a *different*
    # system prompt (bash guideline gone, blank lines no longer collapsed) and
    # the whole provider prefix cache is rewritten once per session.
    #
    # Excluding bash up front makes the startup prompt already match the
    # filtered set: the sanitizer finds nothing to remove, returns the prompt
    # verbatim, and every turn is byte-identical.
    extraArgs = [ "--exclude-tools" "bash" ];

    # Same setup without `extraArgs`/`wrapperAppendSystem`: bash enabled,
    # gated by `bash = "ask"` below.
    unrestrictedBinName = "pi-bash";

    settings = {
      # Must stay false: pi-contextimate (pine-of-glass) anchors its panel on the
      # startup resource listing (`[Context]`/`[Skills]`/... rows), which
      # `showLoadedResources` skips entirely when quietStartup is set — the panel
      # then never installs and silently disappears. The listing is largely
      # subsumed by contextimate's own panel anyway.
      quietStartup = false;
      enableInstallTelemetry = false;

      theme = "base24-ansi";
      themes = [ "${./themes}" ];

      compaction = {
        enabled = false;
      };

      enabledModels = (map (id: "llama-swap/${id}") llamaSwapModels);

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
        "${./extensions/local-agents}/index.ts"
        "${./extensions/system-details}/index.ts"
        "${./extensions/current-date}/index.ts"
        "${./extensions/continue-turn}/index.ts"
        # Diagnostic: logs a line-level diff whenever the wire system prompt
        # changes between provider requests (see pi-cachemire's
        # `cause: system prompt changed`). Drop once the churn is found.
        "${./extensions/prompt-diff}/index.ts"
      ];
    };

    # Lives in the wrapper next to `--exclude-tools bash`, so running the
    # `pi-bash` (bash enabled) doesn't tell the model it has no shell.
    wrapperAppendSystem = ''
      ## Pi Setup Notes

      You have no bash/shell access here: the `bash` tool is denied and a
      curated set of CLI wrappers is registered as individual tools instead.
      Which ones exist depends on the environment (e.g. version control is
      either the `jj-*` or the `git-*` set, never both), so work from the
      registered tools rather than assuming.

      If you need a command that isn't a registered tool, do not work around
      it or fabricate output. Stop and ask the user to add it to the
      `cli-tools` extension.
    '';

    extensionSettings.cli-tools = {
      inherit tarCacheDir;
    };

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
      # The cli-tools `tar` tool writes archives under tarCacheDir and hands
      # the agent their paths for the same reason.
      piInfrastructureReadPaths = [ webFetchCacheDir tarCacheDir ];

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

        # Read-only line-range yank from the file-tools extension (the
        # mutating cut-lines/paste-lines stay on the "ask" default).
        copy-lines = "allow";

        write = "ask";
        edit = "ask";

        # Network egress via the web-fetch extension: gate each call.
        web-fetch = "ask";

        # Outbound file/data upload (exfiltration channel): always confirm.
        upload = "ask";

        # The wrapper excludes bash (`--exclude-tools bash`) in favour of the
        # cli-tools wrappers; this only applies to `pi-bash`
        # (`unrestrictedBinName`).
        bash = "ask";

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

        nix-flake-check = "allow";
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
