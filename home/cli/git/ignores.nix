{ config, pkgs, ... }: {
  programs.git.ignores = [
    "*.rbc"
    "*.pyc"
    "*.o"
    "*.bbl"
    "*.blg"
    "*.fdb_latexmk"
    ".DS_Store"
    "Thumbs.db"
    "*.swp"
    ".clang-tidy"
    ".clangd/"
    ".envrc"
    ".env"
    "compile_commands.json"
    ".bacon-locations"
    ".direnv/"
  ];
}
