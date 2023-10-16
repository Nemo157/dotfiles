{ lib, config, pkgs, ... }: {
  xdg.dataFile = lib.attrsets.mapAttrs' (host: name: {
    name = "applications/${host}.desktop";
    value.text = ''
      [Desktop Entry]
      Type=Application
      Name=${name}
      Icon=Alacritty
      TryExec=alacritty
      Exec=alacritty --class ${name} --command ssh ${host} -t tmux -u new-session -s master-$(hostname -s) -t master -A
      StartupWMClass=${name}
      SingleMainWindow=true
    '';
  }) {
    mithril = "Mithril";
    zinc = "Zinc";
  };
}
