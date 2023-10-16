{ lib, config, pkgs, ... }: {
  xdg.dataFile = {
    "icons/hicolor/256x256/apps/Mithril.png".source = pkgs.fetchurl {
      url = "https://vignette.wikia.nocookie.net/lotrminecraftmod/images/4/41/OreMithril.png/revision/latest?cb=20160602204227";
      name = "OreMithril.png";
      hash = "sha256-gYqs+ILA+IAmnUny7OEphfweXVVBVDpS+Bp3rlDXF54=";
    };

    "icons/hicolor/512x512/apps/Zinc.png".source = pkgs.fetchurl {
      url = "https://img3.wikia.nocookie.net/__cb20120824173419/metallurgy2/images/thumb/c/ca/ZincOre.png/500px-ZincOre.png";
      hash = "sha256-Lf9z28rDfdyoliBcu77g07MntznHLZewz7y2QH8pVb4=";
    };

  } // lib.attrsets.mapAttrs' (host: name: {
    name = "applications/${host}.desktop";
    value.text = ''
      [Desktop Entry]
      Type=Application
      Name=${name}
      Icon=${name}
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
