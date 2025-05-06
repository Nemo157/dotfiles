{ config, pkgs, ... }: {
  imports = [
    ./delta.nix
    ./aliases.nix
    ./ignores.nix
  ];

  programs.git = {
    enable = true;
    extraConfig = {
      advice.detachedHead = false;
      init.defaultBranch = "main";
      core.safecrlf = true;
      blame.ignoreRevsFile = ".git-blame-ignore-revs";
      push = {
        default = "simple";
        autoSetupRemote = true;
        recurseSubmodules = "check";
      };
      pull.ff = "only";
      submodule.fetchJobs = 0;
      color.ui = "auto";
      credential.helper = "cache";
      diff = {
        noprefix = true;
        algorithm = "histogram";
        tool = "vimdiff";
        submodule = "log";
        rust = {
          xfuncname = " *((mod|impl|fn|struct|enum) .*)$";
          wordRegex = "[a-zA-Z_][a-zA-Z0-9_]*|[-+0-9.e]+[fFlL]?|0[xXbB]?[0-9a-fA-F]+[lL]?|[-+*/<>%&^|=!]=|<<=?|>>=?|&&|\\|\\||::|[-=]>|[<>]|[^[:space:]]|[\\xc0-\\xff][\\x80-\\xbf]+";
        };
      };
      log.mailmap = true;
      merge = {
        conflictstyle = "diff3";
        tool = "vimdiff";
      };
      mergetool.keepBackup = false;
      fetch.prune = true;
      gc.auto = 200;
      "url \"git@github.com:\"".pushInsteadOf = "https://github.com/";
      "url \"git@codeberg.org:\"".pushInsteadOf = "https://codeberg.org/";
      "url \"git@gitlab.com:\"".pushInsteadOf = "https://gitlab.com/";
      "url \"git@gist.github.com:\"".pushInsteadOf = "https://gist.github.com/";
    };
  };
}
