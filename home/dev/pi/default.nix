{ config, lib, pkgs, ... }:
let
  configDir = "${config.xdg.configHome}/pi";
  stateDir = "${config.xdg.stateHome}/pi";

  pi-coding-agent = pkgs.unstable.pi-coding-agent;

  settings = {
    defaultProvider = "anthropic";
    defaultModel = "claude-opus-4-7";
    defaultThinkingLevel = "medium";

    quietStartup = true;
    enableInstallTelemetry = false;

    theme = "base24-ansi";
    themes = [ "${./themes}" ];

    packages = [
      (pkgs.callPackage ./extensions/pi-permission-system { }).packageRoot
    ];

    extensions = [
      "${./extensions/cli-tools}/index.ts"
      "${./extensions/edit-toggle}/index.ts"
      "${./extensions/cache-ttl}/index.ts"
    ];
  };

  referenceDirs =
    [ "${pi-coding-agent}/lib/node_modules/pi-monorepo" ]
    ++ settings.packages
    ++ map (builtins.dirOf) settings.extensions;

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
    "pi/settings.json".text = builtins.toJSON settings;

    "pi/APPEND_SYSTEM.md".text = ''

      ## Pi Setup Notes

      You do not have direct bash/shell access in this pi setup. The `bash`
      tool is denied; instead, a curated set of local CLI wrappers is exposed
      as individual tools (e.g. `read`, `edit`, `write`, `rg`, `fd`,
      `jj-status`, `jj-diff`, `jj-log`, `git-status`, `git-diff`, `git-log`).

      If you need a command that isn't available as a registered tool, do not
      try to work around it or fabricate output. Stop and ask the user to add
      the missing tool to the `cli-tools` extension.

      Self-reference directories readable outside the working tree:
      ${lib.concatMapStringsSep "\n" (p: "- ${p}") referenceDirs}
    '';

    "pi/extensions/pi-permission-system/config.json".text = builtins.toJSON {
      # Live-authority chain: our local `edit-toggle` extension registers a
      # link with this name via registerAuthorizer. Naming it here is the
      # opt-in activation — without this entry the link would be inert.
      # See home/dev/pi/extensions/edit-toggle/index.ts.
      authorizerChain = [ "edit-toggle" ];

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
        ]) referenceDirs);
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
