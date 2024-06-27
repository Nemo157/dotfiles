{ pkgs, ... }: {
  imports = [
    ./git
    ./jujutsu.nix
    ./gh.nix
    ./rust
    ./yamllint.nix
  ];

  home.file = {
    ".editorconfig".text = ''
      root = true

      [*]
      end_of_line = lf
      charset = utf-8
      trim_trailing_whitespace = true
      insert_final_newline = true
      indent_style = space
      indent_size = 4
      max_line_length = 80

      [*.rs]
      max_line_length = 100

      [*.nix]
      max_line_length = 100

      [*.md]
      max_line_length = 0

      [*.{ts,js}]
      indent_size = 2

      [*.toml]
      indent_size = 2
    '';
  };
}
