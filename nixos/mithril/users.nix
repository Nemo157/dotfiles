{ pkgs, ... }: {
  users.users.nemo157 = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "tty" "users" "input" "seat" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM2xzZhKE1TzvJmhxT/q4v7vPC1zd9+OOjjaY/GUp73P"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIP7NDZk2lJA+PejK0BiIgzRPX80THcMXzepuxHNiCNdlAAAABHNzaDo="
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIE5gbS2iAoFj4gbPQrvb/YIUN9WL91CKPPeT8brQ71omAAAABHNzaDo="
    ];
  };
}
