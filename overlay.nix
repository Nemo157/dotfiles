{ pkgs-unstable }: (final: prev: {
  # for mullvad exit-node support
  tailscale = pkgs-unstable.tailscale;

  # Requires unreleased change to avoid using `bash` for scripts
  darkman = (prev.darkman.overrideAttrs {
    src = final.fetchgit {
      url = "https://gitlab.com/WhyNotHugo/darkman";
      rev = "df9a5f2a7ad976899bf8f1282a4197a7a632623a";
      sha256 = "sha256-+fGIkTVUP9MVdxOmU45i1+RdK/a6hqPHNvFBq/RHt4U=";
    };
  });

  # Support for showing a system tray with dynamic icons
  eww-wayland = pkgs-unstable.eww-wayland.overrideAttrs (eww-final: eww-prev: rec {
    version = "tray-3-dynamic-icons";
    src = final.fetchFromGitHub {
      owner = "ralismark";
      repo = "eww";
      rev = "485dd6263df6123d41d04886a53715b037cf7aaf";
      hash = "sha256-+iu16EVM5dcR5F83EEFjCXVZv1jwPgJq/EqG6M78sAw=";
    };
    cargoDeps = eww-prev.cargoDeps.overrideAttrs {
      name = "eww-${version}-vendor.tar.gz";
      inherit src;
      outputHash = "sha256-fUTNlAvhfgqrro+4uKyTwQPtoru9AnBHmy0XcOMUfOI=";
    };
    buildInputs = eww-prev.buildInputs ++ [
      final.libdbusmenu-gtk3
    ];
  });

  # contains a fixed pipewire output module
  shairport-sync = prev.shairport-sync.overrideAttrs {
    src = final.fetchFromGitHub {
      owner = "mikebrady";
      repo = "shairport-sync";
      rev = "4447b25a05b648b28c002cd6c7d519e793f4434f";
      sha256 = "sha256-5fuGdKHyG9YFTG7NEc5Rs7WNkFEcP+Pj/O+04zTgbxc=";
    };
  };
})
