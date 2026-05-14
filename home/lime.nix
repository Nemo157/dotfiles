{ lib, ... }: {
  imports = [
    ./cli
    ./common.nix
    ./desktop
    ./dev
    ./personal
  ];

  home = {
    username = "nemo157";
    homeDirectory = "/Users/nemo157";
  };

  home.stateVersion = "25.11";

  programs.claude-code = {
    configDirOverride = false;

    memory = lib.mkAfter ''

      Most projects will have a `.envrc` providing project-specific tools, you need to use `direnv exec` to run these.
      General system or broadly used development tools do not need this and should be available in the environment directly.
    '';
  };
}
