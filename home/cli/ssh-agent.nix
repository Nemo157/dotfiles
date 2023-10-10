{ pkgs, ... }: {
  home.packages = [ pkgs.sshagmux ];

  home.file.".ssh/rc".source = "${pkgs.sshagmux}/ssh/rc";

  systemd.user.services.ssh-agent = {
    Unit = {
      Description = "SSH authentication agent";
      After = "sshagmux.socket";
      BindsTo = "sshagmux.service";
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

  ## doing this overrides the forwarded socket in .ssh/rc somehow,
  ## idk what nixos is doing to break that
  # home.sessionVariables.SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent.socket";

  programs.zsh.profileExtra = ''
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
  '';
}
