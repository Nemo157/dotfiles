{ pkgs, ... }: {
  imports = [
    ./editorconfig.nix
    ./gh.nix
    ./git
    ./jujutsu.nix
    ./rust
    ./yamllint.nix
  ];
}
