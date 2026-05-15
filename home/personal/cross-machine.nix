{ lib, config, pkgs, ... }:

let
  machines = {
    mithril = {
      name = "Mithril";
      icon = pkgs.fetchurl {
        url = "https://vignette.wikia.nocookie.net/lotrminecraftmod/images/4/41/OreMithril.png/revision/latest?cb=20160602204227";
        name = "OreMithril.png";
        hash = "sha256-gYqs+ILA+IAmnUny7OEphfweXVVBVDpS+Bp3rlDXF54=";
      };
    };
    zinc = {
      name = "Zinc";
      icon = pkgs.fetchurl {
        url = "https://img3.wikia.nocookie.net/__cb20120824173419/metallurgy2/images/thumb/c/ca/ZincOre.png/500px-ZincOre.png";
        hash = "sha256-Lf9z28rDfdyoliBcu77g07MntznHLZewz7y2QH8pVb4=";
      };
    };
  };

  kittyBin = "${config.programs.kitty.package}/bin/kitty";

  sshArgs = host:
    "ssh ${host} -t tmux -u new-session -s primary-$(hostname -s) -t primary -A";

  darwinApp = host: { name, icon }: pkgs.runCommand "${name}-app" {} ''
    dir=$out/Applications/${name}.app/Contents
    mkdir -p $dir/MacOS $dir/Resources

    cat > $dir/MacOS/${name} <<'SCRIPT'
    #!/bin/sh
    exec ${kittyBin} --single-instance --instance-group=${host} --title ${name} -o 'shell=${sshArgs host}'
    SCRIPT
    chmod +x $dir/MacOS/${name}

    cat > $dir/Info.plist <<'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleName</key>
      <string>${name}</string>
      <key>CFBundleExecutable</key>
      <string>${name}</string>
      <key>CFBundleIdentifier</key>
      <string>com.nemo157.cross-machine.${host}</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleVersion</key>
      <string>1.0</string>
      <key>LSArchitecturePriority</key>
      <array>
        <string>arm64</string>
        <string>x86_64</string>
      </array>
    </dict>
    </plist>
    PLIST
  '';

in {
  home.packages = lib.optionals pkgs.stdenv.hostPlatform.isDarwin
    (lib.mapAttrsToList darwinApp machines);

  xdg.dataFile = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mapAttrs' (_: { name, icon }: {
      name = "icons/hicolor/256x256/apps/${name}.png";
      value.source = icon;
    }) machines

    // lib.mapAttrs' (host: { name, ... }: {
      name = "applications/${host}.desktop";
      value.text = ''
        [Desktop Entry]
        Type=Application
        Name=${name}
        Icon=${name}
        TryExec=kitty
        Exec=${kittyBin} --class ${name} ${sshArgs host}
        StartupWMClass=${name}
        SingleMainWindow=true
      '';
    }) machines
  );
}
