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
  };

  environment.systemPackages = with pkgs; [
    vim
    man-pages
    man-pages-posix
  ];
}
