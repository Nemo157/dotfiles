{ config, pkgs, ... }: {
  users.mutableUsers = false;

  users.users = {
    nemo157 = {
      isNormalUser = true;
      home = "/home/nemo157";
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = import ../ssh-keys.nix;
      hashedPassword = "$y$j9T$E6IJdj3Qsa1ZUpR4fTNP..$WE5sYB3PmotlsD.IRz6kNuIyWYG4VOLa3yosbVnPNk/";
    };
  };
}
