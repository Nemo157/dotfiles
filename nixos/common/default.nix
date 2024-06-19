{ pkgs, ... }: {
  imports = [
    ./services
  ];

  nix = {
    package = pkgs.nixFlakes;

    daemonIOSchedClass = "idle";
    daemonCPUSchedPolicy = "idle";

    settings = {
      experimental-features = "nix-command flakes";
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    man-pages
    man-pages-posix
  ];

  fonts.packages = with pkgs; [
    liberation_ttf
  ];
}
