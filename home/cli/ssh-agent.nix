{ pkgs, ... }: {
  home.packages = [ pkgs.sshagmux ];

  home.file.".ssh/rc".source = "${pkgs.sshagmux}/ssh/rc";

  systemd.user.services.ssh-agent = {
    Unit = {
      Description = "SSH authentication agent";
      After = "sshagmux.socket";
    };
    Service = {
      Environment = "SSH_AUTH_SOCK=%t/ssh-agent.socket";
      ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a %t/ssh-agent-upstream.socket";
      ExecStartPost = "${pkgs.sshagmux}/bin/sshagmux add-upstream --forward-adds %t/ssh-agent-upstream.socket";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  home.sessionVariables = {
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent.socket";
  };
}