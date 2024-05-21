{ pkgs, ... }: {
  home.packages = with pkgs; [ yamllint ];

  xdg.configFile = {
    "yamllint/config".text = ''
      ---
      extends: default
      rules:
        braces:
          max-spaces-inside: 1
        indentation:
          spaces: 2
          indent-sequences: consistent
        document-start: disable
    '';
  };
}
