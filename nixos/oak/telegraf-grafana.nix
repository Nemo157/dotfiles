{ config, pkgs, ... }:
let
  kindCertDir = "/var/lib/telegraf/kind";

  update-kind-certs = pkgs.writeShellScriptBin "update-kind-certs" ''
    set -euo pipefail

    kubeconfig="''${1:?usage: update-kind-certs <kubeconfig>}"

    if [ ! -f "$kubeconfig" ]; then
      echo "kubeconfig not found: $kubeconfig" >&2
      exit 1
    fi

    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    ${pkgs.yq-go}/bin/yq -r '.users[0].user.client-certificate-data' "$kubeconfig" \
      | base64 -d > "$tmpdir/client.crt"
    ${pkgs.yq-go}/bin/yq -r '.users[0].user.client-key-data' "$kubeconfig" \
      | base64 -d > "$tmpdir/client.key"

    sudo mkdir -p ${kindCertDir}
    sudo cp "$tmpdir/client.crt" "$tmpdir/client.key" ${kindCertDir}/
    sudo chown telegraf:telegraf ${kindCertDir} ${kindCertDir}/client.crt ${kindCertDir}/client.key
    sudo chmod 600 ${kindCertDir}/client.crt ${kindCertDir}/client.key

    echo "updated certs in ${kindCertDir}, restart telegraf to pick them up"
  '';
in
{
  environment.systemPackages = [ update-kind-certs ];

  services.telegraf = {
    extraConfig = {
      inputs = {
        docker = {};
        linux_cpu = {};
        sensors = {};
        kubernetes = {
          url = "https://kind-control-plane:10250";
          bearer_token = "/dev/null";
          tls_cert = "${kindCertDir}/client.crt";
          tls_key = "${kindCertDir}/client.key";
          insecure_skip_verify = true;
        };
      };
      outputs = {
        influxdb = {
          urls = [ "http://127.0.0.1:8086" ];
        };
      };
    };
  };

  systemd.services.telegraf.serviceConfig.StateDirectory = "telegraf";

  users.users.telegraf.extraGroups = [ "docker" ];

  services.influxdb = {
    enable = true;
    extraConfig = {
      http = {
        bind-address = "127.0.0.1:8086";
      };
    };
  };

  services.grafana = {
    enable = true;
    # Some dev stuff is hardcoded to 3001 and not overrideable 😔
    settings.server.http_port = 2998;
  };
}
