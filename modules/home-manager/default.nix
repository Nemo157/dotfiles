{
  imports = [
    ./adaptive-brightness.nix
    ./chatterbox-tts.nix
    ./claude.nix
    ./f5-tts-server.nix
    ./colors.nix
    ./mcp-proxy.nix
    ./opencode.nix
    ./kokoro-fastapi.nix
    ./speaches.nix
    ./md-tui.nix
    ./scripts.nix
  ];

  disabledModules = [
    # Doesn't move files into ~/.config so we use our override above.
    "programs/claude-code.nix"
  ];
}
