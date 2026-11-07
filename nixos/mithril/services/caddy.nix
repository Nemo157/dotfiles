{
  name,
  ts,
  config,
  pkgs,
  lib,
  ...
}:
{
  services.caddy = {
    enable = true;
    email = "mithril.letsencrypt@nemo157.com";

    package = pkgs.caddy.withPlugins {
      plugins = [
        "github.com/tailscale/caddy-tailscale@v0.0.0-20260106222316-bb080c4414ac"
      ];
      hash = "sha256-dhw1ZS/SW7XeZHw4H7xgqGaZofsw6bEIxZE2fl6e9D0=";
    };

    globalConfig = ''
      tailscale {
        auth_key {file.{$CREDENTIALS_DIRECTORY}/tailscale-auth-key}
      }
    '';

    extraConfig = ''
      (tailscale) {
        bind tailscale/{args[0]}
        tls {
          get_certificate tailscale
        }
      }
    '';
  };

  age.secrets = {
    tailscale-auth-key = {
      file = ./tailscale-auth-key.age;
    };
  };

  systemd.services.caddy = {
    serviceConfig = {
      RefreshOnReload = "yes";
      LoadCredential = [
        "tailscale-auth-key:${config.age.secrets.tailscale-auth-key.path}"
      ];
    };
  };

  # caddy-tailscale does not recover its Tailscale connection after the
  # system sleeps; restart caddy once the machine resumes.
  systemd.services.caddy-restart-on-resume = {
    description = "Restart caddy after resume from sleep";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe' pkgs.systemd "systemctl"} --no-block try-restart caddy";
    };
  };
}
