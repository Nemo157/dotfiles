{ ... }: {
  imports = [
    ./editorconfig.nix
    ./gh.nix
    ./git
    ./jujutsu.nix
    ./yamllint.nix
  ];
}
