{ lib, config, pkgs, ... }: {
  programs.mpv = {
    enable = true;
    package = pkgs.mpv.unwrapped.wrapper {
      mpv = pkgs.mpv.unwrapped.override {
        vapoursynthSupport = true;
      };
      scripts = with pkgs.mpvScripts; [ sponsorblock uosc ];
    };
    defaultProfiles = [ "gpu-hq" ];
    profiles = {
      pseudo-gui = {
        idle = "yes";
        keep-open = "yes";
      };
      youtube = {
        profile-cond = "path:find('youtu%.?be')";
        speed = 1.5;
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

      audio-channels = "stereo";

      input-ipc-server = "/tmp/mpvsocket";
    };
  };
  xsession.windowManager.i3.config.floating.criteria = [{
    class = "mpv";
  }];
  wayland.windowManager.sway.config.floating.criteria = [{
    class = "mpv";
  }];
}
