{ lib, config, pkgs, ... }:

let
  generateIcon = { name, stoneColor, oreColor }: pkgs.runCommand "${name}-icon" {
    nativeBuildInputs = [ pkgs.imagemagick ];
    inherit stoneColor oreColor;
  } ''
    mkdir -p $out
    shadow="''${stoneColor}cc"
    magick -size 16x16 xc:"$stoneColor" \
      -fill "$shadow" \
      -draw 'rectangle 0,0 2,1' \
      -draw 'rectangle 5,0 7,0' \
      -draw 'rectangle 13,0 15,1' \
      -draw 'rectangle 0,4 1,5' \
      -draw 'rectangle 3,3 4,3' \
      -draw 'rectangle 9,2 11,3' \
      -draw 'rectangle 14,3 15,4' \
      -draw 'rectangle 0,8 0,9' \
      -draw 'rectangle 4,7 5,8' \
      -draw 'rectangle 12,6 13,7' \
      -draw 'rectangle 0,13 1,14' \
      -draw 'rectangle 6,12 8,13' \
      -draw 'rectangle 10,11 11,11' \
      -draw 'rectangle 14,13 15,15' \
      -fill "$oreColor" \
      -draw 'rectangle 2,2 4,4' \
      -draw 'rectangle 6,1 8,3' \
      -draw 'rectangle 10,4 13,6' \
      -draw 'rectangle 1,6 3,8' \
      -draw 'rectangle 7,8 9,10' \
      -draw 'rectangle 2,10 4,12' \
      -draw 'rectangle 11,12 14,14' \
      -draw 'rectangle 5,14 7,15' \
      -depth 8 -define png:color-type=6 \
      \( +clone -filter point -resize 16x16 -write $out/icon_16x16.png +delete \) \
      \( +clone -filter point -resize 32x32 -write $out/icon_32x32.png +delete \) \
      \( +clone -filter point -resize 128x128 -write $out/icon_128x128.png +delete \) \
      \( +clone -filter point -resize 256x256 -write $out/icon_256x256.png +delete \) \
      -filter point -resize 512x512 $out/icon_512x512.png
  '';

  machines = {
    mithril = {
      name = "Mithril";
      icon = generateIcon {
        name = "mithril";
        stoneColor = "#6b6b6b";
        oreColor = "#a8c8e8";
      };
    };
    zinc = {
      name = "Zinc";
      icon = generateIcon {
        name = "zinc";
        stoneColor = "#6b6b6b";
        oreColor = "#8bab7a";
      };
    };
  };

  kittyBin = "${config.programs.kitty.package}/bin/kitty";

  sshArgs = host:
    "ssh ${host} -t tmux -u new-session -s primary-$(hostname -s) -t primary -A";

  darwinApp = host: { name, icon }: pkgs.runCommand "${name}-app" {
    nativeBuildInputs = [ pkgs.libicns ];
  } ''
    dir=$out/Applications/${name}.app/Contents
    mkdir -p $dir/MacOS $dir/Resources

    png2icns $dir/Resources/${name}.icns ${icon}/icon_*.png

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
      <key>CFBundleIconFile</key>
      <string>${name}</string>
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
      value.source = "${icon}/icon_256x256.png";
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
