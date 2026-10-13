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

      rebase = {
        skip-emptied = true;
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
        # padded to fit "+9999/-999" (with "(empty)" centered on the "/"),
        # longer diffs just push the line out
        "format_diff_stat(commit)" = ''
          if(commit.empty(),
            "  " ++ label("empty", "(empty)") ++ " ",
            concat(
              pad_start(5, label("diff added", "+" ++ commit.diff().stat().total_added())),
              "/",
              pad_end(4, label("diff removed", "-" ++ commit.diff().stat().total_removed())),
            )
          )
        '';
        log_compact = ''
          if(root,
            format_root_commit(self),
            label(if(current_working_copy, "working_copy"),
              concat(
                separate(" ",
                  format_short_change_id_with_change_offset(self),
                  format_short_commit_id(commit_id),
                  format_diff_stat(self),
                  if(self.contained_in('first_parent(@)'), label("git_head", "HEAD")),
                  bookmarks,
                  tags,
                  working_copies,
                  if(conflict, label("conflict", "conflict")),
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
        "all" = "all()";
        "private()" = "description('private:*')";
      };

      fileset-aliases = {
        "LOCKFILES" = "**/Cargo.lock | **/flake.lock | **/package-lock.json | **/deno.lock";
        "DEFAULT-GENERATED" = "LOCKFILES";
        "GENERATED" = "DEFAULT-GENERATED | LOCAL-GENERATED";
        "not:x" = "~x";

        # to be overridden per-repo
        "LOCAL-GENERATED" = "none()";
      };

      aliases = {
        sh = ["util" "exec" "--" "bash" "-c" ''jj log --no-graph -p -T builtin_log_detailed -r "''${1:-@}" -- not:GENERATED'' "jj-sh"];
        lo = ["log" "-r" "current"];
        f = ["git" "fetch" "--all-remotes"];
        redundancy-reduction = ["util" "exec" "--" (lib.getExe (pkgs.writeShellApplication {
          name = "jj-redundancy-reduction";
          runtimeInputs = [ pkgs.jujutsu ];
          text = ''jj rebase -s "exactly($1, 1)" -d "exactly($1, 1)-~::exactly($1, 1)--"'';
        }))];
      };

      git = {
        fetch = ["origin" "upstream"];
        private-commits = "private()";
      };
    };
  };
}
