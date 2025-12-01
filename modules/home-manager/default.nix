{
  imports = [
    ./claude.nix
    ./linear-cli.nix
    ./md-tui.nix
    ./scripts.nix
  ];

  disabledModules = [
    # Doesn't move files into ~/.config so we use our override above.
    "programs/claude-code.nix"
  ];
}
