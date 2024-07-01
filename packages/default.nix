{ pkgs }: {
  gh-poi = pkgs.callPackage ./gh-poi.nix { };

  rust-shim = pkgs.callPackage ./rust-shim.nix { };

  cargo-dl = pkgs.callPackage ./cargo-dl.nix { };

  cargo-doc-like-docs-rs = pkgs.writeShellApplication {
    name = "cargo-doc-like-docs-rs";
    runtimeInputs = [ pkgs.jq ];
    text = pkgs.lib.readFile ./cargo-doc-like-docs-rs.sh;
  };

  cargo-minimal-versions = pkgs.callPackage ./cargo-minimal-versions.nix { };

  cargo-rubber = pkgs.writeShellApplication {
    name = "cargo-rubber";
    runtimeInputs = [ pkgs.bubblewrap pkgs.jq ];
    text = pkgs.lib.readFile ./cargo-rubber.sh;
  };

  cbor-diag-rs = pkgs.callPackage ./cbor-diag-rs.nix { };

  zebra = pkgs.writeShellApplication {
    name = "zebra";
    text = pkgs.lib.readFile ./zebra.sh;
  };

  # TODO: needs zsh
  # cargo-rustdoc-clippy = pkgs.writeShellApplication {
  #   name = "cargo-rustdoc-clippy";
  #   text = pkgs.lib.readFile ./cargo-rustdoc-clippy.sh;
  # };

  sshagmux = pkgs.callPackage ./sshagmux.nix { };
}
