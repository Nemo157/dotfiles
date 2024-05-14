{ config, pkgs, ... }: let
  ssh-keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIN0g9YhXofS5DOZJZP5Ji38bhxbFgA9LcBWMrZ2sFooTAAAABHNzaDo= nemo157@mithril"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINPdciLKw1xWMzKVeacAUOtqkfd8GyAfpSJTl/NodScKAAAABHNzaDo= nemo157@zinc"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIP7NDZk2lJA+PejK0BiIgzRPX80THcMXzepuxHNiCNdlAAAABHNzaDo="
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIE5gbS2iAoFj4gbPQrvb/YIUN9WL91CKPPeT8brQ71omAAAABHNzaDo="
  ];
in {
  programs = {
    zsh.enable = true;
  };

  users.users = {
    root = {
      openssh.authorizedKeys.keys = ssh-keys;
    };

    nemo157 = {
      isNormalUser = true;
      hashedPassword = "$y$j9T$E6IJdj3Qsa1ZUpR4fTNP..$WE5sYB3PmotlsD.IRz6kNuIyWYG4VOLa3yosbVnPNk/";

      openssh.authorizedKeys.keys = ssh-keys;

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
