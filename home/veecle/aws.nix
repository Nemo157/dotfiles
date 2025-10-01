{ config, pkgs, ... }: {
  home.packages = [
    pkgs.awscli2
    pkgs.ssm-session-manager-plugin
  ];

  age.secrets.veecle-aws-credentials.file = ./aws-credentials.age;

  home.sessionVariables = {
    AWS_CONFIG_FILE = "${config.xdg.configHome}/aws/config";
    AWS_SHARED_CREDENTIALS_FILE = config.age.secrets.veecle-aws-credentials.path;
  };

  xdg.configFile."aws/config".text = ''
    [default]
    region=eu-central-1
  '';
}
