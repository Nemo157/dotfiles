{ config, pkgs, ... }: {
  users.mutableUsers = false;

  users.users = {
    nemo157 = {
      isNormalUser = true;
      home = "/home/nemo157";
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = import ../ssh-keys.nix;
    };
  };
}
