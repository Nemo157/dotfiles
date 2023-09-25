{ lib, config, pkgs, ... }: {
  programs.mpv = {
    enable = true;
    defaultProfiles = [ "gpu-hq" ];
    profiles = {
      pseudo-gui = {
        idle = "yes";
        keep-open = "yes";
      };
    };
    config = {
      scale = "ewa_lanczossharp";
      cscale = "ewa_lanczossharp";
      video-sync = "display-resample";
      interpolation = "yes";
      tscale = "oversample";

      border = "no";

      hwdec = "auto-copy";
      hwdec-codecs = "all";

      resume-playback = "no";

      ontop = "yes";
      snap-window = "yes";
      autofit = "37%";
      geometry = "100%:100%";
    };
  };
  xsession.windowManager.i3.config.floating.criteria = [{
    class = "mpv";
  }];
  wayland.windowManager.sway.config.floating.criteria = [{
    class = "mpv";
  }];
}
