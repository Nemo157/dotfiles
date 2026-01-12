{ config, pkgs, ... }: {
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "base24-eink2";
      plus-style = "syntax 18";
      plus-emph-style = "black green";
      plus-empty-line-marker-style = "green normal";
      minus-style = "normal 18";
      minus-emph-style = "black red";
      minus-empty-line-marker-style = "red normal";
      keep-plus-minus-markers = "true";
      line-numbers = "true";
      line-numbers-minus-style = "red 18";
      line-numbers-zero-style = "normal 18";
      line-numbers-plus-style = "green 18";
      line-numbers-left-format = "{nm:>4} ";
      line-numbers-left-style = "white 18";
      line-numbers-right-format = "{np:>4} ";
      line-numbers-right-style = "white 18";
      hunk-header-style = "black black";
      hunk-header-decoration-style = "plain";
      commit-style = "raw";
      file-style = "white";
      file-decoration-style = "white box";
    };
  };
}
