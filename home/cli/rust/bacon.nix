{
  programs.bacon = {
    enable = true;
    settings = {
      summary = true;
      wrap = false;
      reverse = false;

      export_locations = true;

      default_job = "clippy";

      keybindings = {
        r = "toggle-raw-output";
        shift-r = "rerun";
        g = "scroll-to-top";
        shift-g = "scroll-to-bottom";
        k = "scroll-lines(-1)";
        j = "scroll-lines(1)";
      };

      jobs = {
        check.command = [
          "cargo" "rubber"
          "check"
          "--workspace"
          "--all-targets"
          "--all-features"
          "--color" "always"
        ];

        clippy.command = [
          "cargo" "rubber"
          "clippy"
          "--workspace"
          "--all-targets"
          "--all-features"
          "--color" "always"
        ];

        deny = {
          command = [
            "cargo"
            "deny"
            "--workspace"
            "--all-features"
            "--locked"
            "check"
            "--allow" "duplicate"
          ];
          need_stdout = true;
        };

        doc.command = [
          "cargo" "rubber"
          "doc"
          "--no-deps"
          "--color" "always"
        ];

        test = {
          command = [
            "cargo" "rubber"
            "test"
            "--workspace"
            "--all-features"
            "--color" "always"
            "--"
            "--color" "always"
          ];
          need_stdout = true;
        };
      };
    };
  };
}
