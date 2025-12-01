{ config, pkgs, ... }: {
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "eink2";
      plus-style = "syntax black";
      plus-emph-style = "white green";
      plus-empty-line-marker-style = "green normal";
      minus-style = "normal black";
      minus-emph-style = "white red";
      minus-empty-line-marker-style = "red normal";
      keep-plus-minus-markers = "true";
      line-numbers = "true";
      line-numbers-minus-style = "red black";
      line-numbers-zero-style = "normal black";
      line-numbers-plus-style = "green black";
      line-numbers-left-format = "{nm:>4} ";
      line-numbers-left-style = "white black";
      line-numbers-right-format = "{np:>4} ";
      line-numbers-right-style = "white black";
      hunk-header-style = "brightblack brightblack";
      hunk-header-decoration-style = "plain";
      commit-style = "raw";
      file-style = "white";
      file-decoration-style = "white box";
    };
  };
}
