{ lib, pkgs, ... }: {
  scripts.jj-ws.text = ''
    branch="$1"
    slug="$(echo "$branch" | tr '/' '-')"
    jj workspace add "../$slug"
    cd "../$slug"
    jj new "$branch"@origin
  '';

  programs.jujutsu = {
    enable = true;
    package = pkgs.unstable.jujutsu;
    settings = {
      ui = {
        pager = ["env" "LESSANSIENDCHARS=Km" "less" "-RF"];
        diff-formatter = "delta";
        always-allow-large-revsets = true;
      };

      merge-tools = {
        delta = {
          program = lib.getExe (pkgs.writeShellApplication {
            name = "delta";
            runtimeInputs = [pkgs.delta];
            text = ''
              cd "$(dirname "$1")"
              delta "$(basename "$1")" "$(basename "$2")" || true
            '';
          });
        };
        difftastic = {
          program = lib.getExe pkgs.difftastic;
          diff-args = [ "--color=always" "$left" "$right" ];
        };
      };

      snapshot = {
        auto-update-stale = true;
      };

      colors = {
        rest = "bright blue";
        tags = "yellow";
        bookmark = "cyan";
        bookmarks = "blue";
        local_bookmarks = "green";
        remote_bookmarks = "red";

        elided = "bright cyan";
        "node elided" = "bright cyan";

        "working_copy change_id" = "magenta";
        "working_copy commit_id" = "blue";
        "working_copy author" = "yellow";
        "working_copy committer" = "yellow";
        "working_copy timestamp" = "cyan";
        "working_copy working_copies" = "green";
        "working_copy bookmark" = "magenta";
        "working_copy bookmarks" = "magenta";
        "working_copy local_bookmarks" = "magenta";
        "working_copy remote_bookmarks" = "magenta";
        "working_copy tag" = "magenta";
        "working_copy tags" = "magenta";
        "working_copy git_refs" = "green";
        "working_copy divergent" = "red";
        "working_copy divergent change_id" = "red";
        "working_copy conflict" = "red";
        "working_copy empty" = "green";
        "working_copy placeholder" = "red";
        "working_copy description placeholder" = "yellow";
        "working_copy empty description placeholder" = "green";
      };

      templates = {
        log = "log_compact";
      };
      template-aliases = {
        "format_timestamp(timestamp)" = "timestamp.ago()";
        log_compact = ''
          if(root,
            format_root_commit(self),
            label(if(current_working_copy, "working_copy"),
              concat(
                separate(" ",
                  format_short_change_id_with_hidden_and_divergent_info(self),
                  format_short_commit_id(commit_id),
                  if(git_head, label("git_head", "HEAD")),
                  bookmarks,
                  tags,
                  working_copies,
                  if(conflict, label("conflict", "conflict")),
                  if(empty, label("empty", "(empty)")),
                  if(description, description.first_line(), description_placeholder),
                  format_short_signature(author),
                  format_timestamp(committer.timestamp()),
                ) ++ "\n",
              ),
            )
          )
        '';
      };

      revsets = {
        "log" = "@ | ancestors(immutable_heads()..interesting_heads, 2) | trunk()";
      };
      revset-aliases = {
        "current" = "ancestors(trunk()..@, 2) | trunk() | @-::";
        "pulls" = "remote_bookmarks(pulls/)";
        "interesting_heads" = "visible_heads() ~ remote_bookmarks() | bookmarks()";
        "trunk" = "trunk()";
      };

      aliases = {
        lo = ["log" "-r" "current"];
        f = ["git" "fetch" "--all-remotes"];
      };

      git = {
        fetch = ["origin" "upstream"];
      };

      fix.tools = {
        rustfmt = {
          command = ["rustfmt" "--edition" "2021"];
          patterns = ["glob:**/*.rs"];
        };
        taplo = {
          command = ["taplo" "fmt" "--stdin-filepath=$path" "-"];
          patterns = ["glob:**/*.toml"];
        };
      };
    };
  };
}
