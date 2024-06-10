{ config, ... }: {
  age.secrets.restic-b2-key = {
    file = ./restic-b2-key.age;
    owner = "nemo157";
    group = "users";
  };
  age.secrets.restic-b2-password = {
    file = ./restic-b2-password.age;
    owner = "nemo157";
    group = "users";
  };

  services.restic.backups = {
    zinc-nemo157 = {
      repository = "s3:s3.us-west-001.backblazeb2.com/verbalize-craftwork-stray";
      environmentFile = config.age.secrets.restic-b2-key.path;
      passwordFile = config.age.secrets.restic-b2-password.path;
      extraBackupArgs = [ "--exclude-caches" "--verbose" ];
      initialize = true;
      user = "nemo157";
      paths = [ "/home/nemo157" ];
      exclude = [
        "/home/nemo157/.cache"
        "/home/nemo157/.local/share/flatpak"
        "/home/nemo157/.local/share/containers"
      ];
    };
  };
}
