{ ... }: {
  programs = {
    gh = {
      enable = true;
      settings = {
        prompt = "enabled";
        aliases = {
          co = "pr checkout --detach";
          conflicts = ''
            pr list --json number,title,mergeable,headRefName --jq '.[] | select(.mergeable == "CONFLICTING") | "\(.number) \(.headRefName): \(.title)"'
          '';
        };
      };
    };
  };

  # Fuck 16-bit color codes
  home.sessionVariables.GLAMOUR_STYLE = "ascii";
}
