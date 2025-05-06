{ pkgs, ... }: {
  imports = [
    ./services
  ];

  nix = {
    daemonIOSchedClass = "idle";
    daemonCPUSchedPolicy = "idle";

    settings = {
      experimental-features = "nix-command flakes";
    };

    gc = {
      automatic = true;
      options = "--delete-older-than +20";
    };

    optimise = {
      automatic = true;
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
