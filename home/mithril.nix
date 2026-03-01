{ lib, config, pkgs, ts, hostname, ... }: {
  imports = [
    ./age.nix
    ./audio.nix
    ./chill
    ./chill-server
    ./cli
    ./common.nix
    ./desktop
    ./dev
    ./personal
    ./xdg.nix
  ];

  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";

  home.packages = with pkgs; [
    stc-cli
    flatpak
    amdgpu_top
  ];

  services.syncthing = {
    enable = true;
    tray.enable = true;
    guiAddress = "${ts.ips.mithril}:8384";
  };

  age.secrets.hf-token.file = ./hf-token.age;

  services.chatterbox-tts = {
    enable = true;
    environmentFile = config.age.secrets.hf-token.path;
  };

  services.f5-tts-server = {
    enable = true;
    hostname = ts.self.ip;
  };

  services.kokoro-fastapi = {
    enable = true;
    hostname = ts.self.ip;

    environment = {
      CORS_ORIGINS = ''["http://${ts.self.host}:8080"]'';
    };
  };

  services.speaches = {
    enable = true;
    hostname = ts.self.ip;

    environment = {
      ALLOW_ORIGINS = ''["http://${ts.self.host}:8080"]'';
    };
  };

  services.ollama = {
    host = ts.self.ip;
    environmentVariables = {
      OLLAMA_ORIGINS = "http://${ts.self.host}:8080";
    };
  };
  home.sessionVariables = {
    OLLAMA_HOST = "${config.services.ollama.host}:${toString config.services.ollama.port}";
  };

  services.opencode.hostname = ts.ips.mithril;

  programs.opencode = {
    settings = {
      model = "openrouter/z-ai/glm-5";
      small_model = "openrouter/minimax/minimax-m2.5";

      provider = {
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (local)";
          options = {
            baseURL = "http://${ts.self.host}:11434/v1";
          };
          models = {
            "ministral-3:14B-16k".name = "ministral-3:14B-16k";
            "ministral-3:14B-96k".name = "ministral-3:14B-96k";
            "ministral-3:8B-96k".name = "ministral-3:8B-96k";
            "ministral-3:14B-128k".name = "ministral-3:14B-128k";
            "lfm2.5-thinking:1.2b-128k".name = "lfm2.5-thinking:1.2b-128k";
          };
        };

        openrouter = {
          models = {
            "z-ai/glm-5" = {};
            "minimax/minimax-m2.5" = {};
          };
        };
      };
    };
  };
}
