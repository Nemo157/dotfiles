{ lib, config, ... }: {
  age.secrets.veecle-ssh-config.file = ./ssh-config.age;
  age.secrets.veecle-known-hosts.file = ./known-hosts.age;

  programs.ssh = {
    includes = [
      config.age.secrets.veecle-ssh-config.path
    ];
    userKnownHostsFile = lib.mkForce "~/.ssh/known_hosts.new ${config.age.secrets.veecle-known-hosts.path} ~/.ssh/known_hosts";
  };
}
