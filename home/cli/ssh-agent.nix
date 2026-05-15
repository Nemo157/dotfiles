{ pkgs, lib, config, ... }:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  socketDir =
    if isDarwin then "$TMPDIR/sshagmux"
    else "$XDG_RUNTIME_DIR";

  shared = {
    home.packages = [ pkgs.sshagmux ];

    home.file.".ssh/rc".text = ''
      MUX="${socketDir}/ssh-agent.socket"
      if [ -n "$SSH_AUTH_SOCK" -a -S "$SSH_AUTH_SOCK" -a -S "$MUX" ]; then
        SSH_AUTH_SOCK="$MUX" ${pkgs.sshagmux}/bin/sshagmux add-upstream "$SSH_AUTH_SOCK"
      fi
    '';

    ## using home.sessionVariables overrides the forwarded socket in .ssh/rc on NixOS
    programs.zsh.profileExtra = ''
      export SSH_AUTH_SOCK="${socketDir}/ssh-agent.socket"
    '';
  };

  linux = {
    systemd.user.services.ssh-agent = {
      Unit = {
        Description = "SSH authentication agent";
        After = "sshagmux.socket";
        BindsTo = "sshagmux.socket";
      };
      Service = {
        Environment = "SSH_AUTH_SOCK=%t/ssh-agent.socket";
        ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a %t/ssh-agent-upstream.socket";
        ExecStartPost = [
          "${pkgs.coreutils}/bin/sleep 1"
          "${pkgs.sshagmux}/bin/sshagmux add-upstream --forward-adds %t/ssh-agent-upstream.socket"
        ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

  darwin = {
    launchd.agents = {
      sshagmux = {
        enable = true;
        config = {
          ProgramArguments = [ "${pkgs.writeShellScript "sshagmux-start" ''
            mkdir -p "$TMPDIR/sshagmux"
            rm -f "$TMPDIR/sshagmux/ssh-agent.socket"
            exec ${pkgs.sshagmux}/bin/sshagmux daemon --bind-address "$TMPDIR/sshagmux/ssh-agent.socket"
          ''}" ];
          KeepAlive = true;
          RunAtLoad = true;
        };
      };
      ssh-agent = {
        enable = true;
        config = {
          ProgramArguments = [ "${pkgs.writeShellScript "ssh-agent-start" ''
            mkdir -p "$TMPDIR/sshagmux"
            rm -f "$TMPDIR/sshagmux/ssh-agent-upstream.socket"
            ${pkgs.openssh}/bin/ssh-agent -D -a "$TMPDIR/sshagmux/ssh-agent-upstream.socket" &
            AGENT_PID=$!
            sleep 1
            SSH_AUTH_SOCK="$TMPDIR/sshagmux/ssh-agent.socket" \
              ${pkgs.sshagmux}/bin/sshagmux add-upstream --forward-adds "$TMPDIR/sshagmux/ssh-agent-upstream.socket"
            wait $AGENT_PID
          ''}" ];
          KeepAlive = true;
          RunAtLoad = true;
        };
      };
    };
  };
in
  lib.mkMerge [
    shared
    (lib.mkIf isLinux linux)
    (lib.mkIf isDarwin darwin)
  ]
