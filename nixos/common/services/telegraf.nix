{ lib, config, pkgs, ... }: {
  services.telegraf = {
    enable = true;
    extraConfig = {
      inputs = {
        cgroup = {
          paths = [
            "/sys/fs/cgroup"
            "/sys/fs/cgroup/system.slice"
            "/sys/fs/cgroup/system.slice/*.service"
            "/sys/fs/cgroup/user.slice"
            "/sys/fs/cgroup/user.slice/user-1000.slice"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/app-*.scope"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/app-*.slice"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/app-*.slice/app-*.scope"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/*.service"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/background.slice"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/background.slice/*.service"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/session.slice"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/session.slice/*.service"
          ];
          files = [
            "cgroup.stat"
            "cpu.stat"
            "memory.current"
            "memory.swap.current"
            "pids.current"
          ];
        };
        cpu = {};
        disk = {};
        diskio = {};
        mem = {};
        net = {
          ignore_protocol_stats = true;
        };
        netstat = {};
        processes = {};
        swap = {};
        temp = {};
      };
    };
  };

  systemd.services.telegraf.path = lib.mkIf
    (config.services.telegraf.extraConfig.inputs ? sensors)
    [ pkgs.lm_sensors ];
}
