{ pkgs, ... }: {
  users.users.nemo157 = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "tty" "users" "input" "seat" "docker" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = import ../ssh-keys.nix;
  };
}
