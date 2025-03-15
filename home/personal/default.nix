{ config, lib, pkgs, ... }: {
  imports = [
    ./atuin.nix
    ./cross-machine.nix
    ./git.nix
    ./jujutsu.nix
    ./ssh.nix
  ];

  home.packages = with pkgs; [
    calibre
  ];

  # Tray isn't available until eww starts up
  systemd.user.services.syncthingtray.Service.ExecStart = lib.mkIf config.services.syncthing.enable
    (lib.mkForce "${lib.getExe' pkgs.syncthingtray-minimal "syncthingtray"} --wait");
}
