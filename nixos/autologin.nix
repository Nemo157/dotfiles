{ lib, config, pkgs, ... }: {
  # Only override tty1 to autologin, leave the others manual
  # based on https://github.com/NixOS/nixpkgs/blob/592047fc9e4f7b74a4dc85d1b9f5243dfe4899e3/nixos/modules/services/ttys/getty.nix
  systemd.services."getty@tty1" = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      "" # override upstream default with an empty ExecStart
      "@${pkgs.util-linux}/sbin/agetty agetty ${lib.escapeShellArgs ["--login-program" "${config.services.getty.loginProgram}"]} --autologin nemo157 --noclear --keep-baud %I 115200,38400,9600 $TERM"
    ];
    restartIfChanged = false;
  };
}
