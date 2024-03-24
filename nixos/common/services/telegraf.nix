{ pkgs, ts, ... }: {
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
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/app-*.scope"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/*.service"
            "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/background.slice/*.service"
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
        linux_cpu = {};
        mem = {};
        net = {
          ignore_protocol_stats = true;
        };
        netstat = {};
        processes = {};
        sensors = {};
        swap = {};
        temp = {};
      };
      outputs = {
        influxdb = {
          urls = [ "http://${ts.mithril.host}:8086" ];
        };
      };
    };
  };

  systemd.services.telegraf.path = [ pkgs.lm_sensors ];
}
