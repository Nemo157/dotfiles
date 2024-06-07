{ lib, pkgs, ... }: {
  programs.jujutsu = {
    enable = true;
    settings = {
      ui = {
        pager = ["env" "LESSANSIENDCHARS=Km" "less" "-RF"];
        diff.tool = "delta";
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
      };
      colors = {
        rest = "bright cyan";
        tags = "yellow";
        branch = "cyan";
        branches = "blue";
        local_branches = "green";
        remote_branches = "red";
      };
      templates = {
        log = "log_compact";
      };
      template-aliases = {
        "format_timestamp(timestamp)" = "timestamp.ago()";
        log_compact = ''
          if(root,
            builtin_log_root(change_id, commit_id),
            label(if(current_working_copy, "working_copy"),
              concat(
                separate(" ",
                  builtin_change_id_with_hidden_and_divergent_info,
                  format_short_commit_id(commit_id),
                  git_head,
                  branches,
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
        "pulls" = "remote_branches(pulls/)";
        "interesting_heads" = "visible_heads() ~ remote_branches() | branches()";
      };
      aliases = {
        lo = ["log" "-r" "current"];
        f = ["git" "fetch" "--all-remotes"];
      };
      git = {
        fetch = ["origin" "upstream"];
      };
    };
  };
}
