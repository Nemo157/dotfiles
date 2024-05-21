{ pkgs }: {
  gh-poi = pkgs.callPackage ./gh-poi.nix { };

  rust-shim = pkgs.callPackage ./rust-shim.nix { };

  cargo-dl = pkgs.callPackage ./cargo-dl.nix { };

  cargo-doc-like-docs-rs = pkgs.writeShellApplication {
    name = "cargo-doc-like-docs-rs";
    runtimeInputs = [ pkgs.jq ];
    text = pkgs.lib.readFile ./cargo-doc-like-docs-rs;
  };

  cargo-minimal-versions = pkgs.callPackage ./cargo-minimal-versions.nix { };

  cargo-rubber = pkgs.writeShellApplication {
    name = "cargo-rubber";
    runtimeInputs = [ pkgs.bubblewrap pkgs.jq ];
    text = pkgs.lib.readFile ./cargo-rubber;
  };

  zebra = pkgs.writeShellApplication {
    name = "zebra";
    text = pkgs.lib.readFile ./zebra;
  };

  # TODO: needs zsh
  # cargo-rustdoc-clippy = pkgs.writeShellApplication {
  #   name = "cargo-rustdoc-clippy";
  #   text = pkgs.lib.readFile ./cargo-rustdoc-clippy;
  # };

  sshagmux = pkgs.callPackage ./sshagmux.nix { };
}
