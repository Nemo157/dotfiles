{ config, pkgs, ... }: {
  programs = {
    zsh.enable = true;
  };

  users.users = {
    root = {
      openssh.authorizedKeys.keys = import ../ssh-keys.nix;
    };

    nemo157 = {
      isNormalUser = true;
      hashedPassword = "$y$j9T$E6IJdj3Qsa1ZUpR4fTNP..$WE5sYB3PmotlsD.IRz6kNuIyWYG4VOLa3yosbVnPNk/";

      openssh.authorizedKeys.keys = import ../ssh-keys.nix;

      extraGroups = [
        "docker"
        "input"
        "networkmanager"
        "seat"
        "tty"
        "users"
        "video"
        "wheel"
        "wireshark"
      ];

      shell = pkgs.zsh;

      homeMode = "710";
    };
  };
}
