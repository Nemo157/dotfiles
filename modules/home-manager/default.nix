{
  imports = [
    ./claude.nix
    ./colors.nix
    ./linear-cli.nix
    ./opencode.nix
    ./md-tui.nix
    ./scripts.nix
  ];

  disabledModules = [
    # Doesn't move files into ~/.config so we use our override above.
    "programs/claude-code.nix"
  ];
}
