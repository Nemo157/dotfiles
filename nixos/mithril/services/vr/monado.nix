{
  services.monado = {
    enable = true;
    defaultRuntime = true;
    highPriority = true;
  };

  systemd.user.services.monado = {
    environment = {
      STEAMVR_LH_ENABLE = "1";
      IPC_EXIT_WHEN_IDLE = "1";
    };
  };
}
