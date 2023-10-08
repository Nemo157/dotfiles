
{ pkgs, ... }: {
  users.users.nemo157 = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = import ../ssh-keys.nix;
  };

  services.getty.autologinUser = "nemo157";
}
