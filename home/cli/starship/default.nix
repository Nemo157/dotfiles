{ config, pkgs, lib, ... }:
let
  jj-ai-branch-summary = pkgs.writeShellApplication {
    name = "jj-ai-branch-summary";
    runtimeInputs = [ pkgs.jujutsu pkgs.jq ];
    text = builtins.readFile ./jj-ai-branch-summary.sh;
  };
in
{
  programs.starship = {
    enable = true;
    settings = {
      format = ''
        $username[@](green dimmed)$hostname $directory$git_branch$git_commit$git_state$git_status''${custom.jj_summary}$all
        $jobs$battery$time($status )$cmd_duration$character
      '';

      aws.symbol = " ";
      aws.disabled = true;

      battery = {
        full_symbol = "";
        charging_symbol = "";
        discharging_symbol = "";
      };

      character = {
        success_symbol = "→";
        error_symbol = "[→](red)";
        vicmd_symbol = "[↓](yellow)";
      };

      cmd_duration.style = "purple";

      directory.style = "purple";
      directory.truncate_to_repo = false;

      conda.symbol = " ";

      dotnet.style = "blue";
      dotnet.symbol = " ";

      env_var.SHLVL = {
        format = "SHLVL=[$env_value]($style)";
        style = "cyan";
      };

      env_var.SCRATCH = {
        format = "SCRATCH=[$env_value]($style)";
        style = "cyan";
      };

      git_branch.style = "yellow";
      git_branch.symbol = " ";
      git_branch.disabled = true;

      git_commit.style = "green";
      git_commit.disabled = true;

      git_status.style = "red";
      git_status.disabled = true;

      git_state.disabled = true;

      golang.style = "cyan";
      golang.symbol = " ";

      hg_branch.symbol = " ";

      hostname.format = "[$hostname]($style)";
      hostname.style = "green";
      hostname.ssh_only = false;

      java.symbol = " ";

      line_break.disabled = true;

      memory_usage.symbol = " ";

      nodejs.style = "green";
      nodejs.symbol = " ";

      package.style = "orange";
      package.symbol = " ";

      php.style = "red";
      php.symbol = " ";

      python.style = "yellow";
      python.symbol = " ";

      ruby.style = "red";
      ruby.symbol = " ";

      rust.style = "red";
      rust.symbol = " ";

      status = {
        disabled = false;
        symbol = "●";
        success_symbol = "○";
        not_executable_symbol = "◓";
        not_found_symbol = "◐";
        sigint_symbol = "◒";
        signal_symbol = "⚡";
        format = "[$symbol( $common_meaning)( SIG$signal_name)( $maybe_int)]($style)";
        pipestatus_separator = " | ";
        pipestatus_format = "\\[ $pipestatus \\] → [$symbol($common_meaning)(SIG$signal_name)($maybe_int)]($style)";
        map_symbol = true;
        pipestatus = true;
      };

      time = {
        disabled = false;
        format = "[$time]($style) ";
        style = "yellow";
        time_format = "%H:%M";
      };

      username = {
        format = "[$user]($style)";
        style_user = "green";
        show_always = true;
      };

      custom.jj_summary = {
        command = lib.getExe jj-ai-branch-summary;
        when = "jj root";
        symbol = " ";
        style = "yellow";
      };
    };
  };
}
