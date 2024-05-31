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
    # Because of https://github.com/Canop/bacon/issues/157 need to create an
    # empty bacon.toml in all repos to use it...
    "bacon.toml"
    ".cargo/"
  ];
}
