{ config, pkgs, ... }: {
  programs.git.ignores = [
    # ruby
    "*.rbc"
    # python
    "*.pyc"
    # latex (i think)
    "*.bbl"
    "*.blg"
    "*.fdb_latexmk"
    # silly OS
    ".DS_Store"
    "Thumbs.db"
    # unconfigured vim
    "*.swp"
    # c
    "*.o"
    ".clang-tidy"
    ".clangd/"
    "compile_commands.json"
  ];
}
