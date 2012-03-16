# This ensures ESC-h can get help on zsh builtins

autoload run-help

potential_paths=(
  /usr/share/zsh
)

for potential_path in potential_paths
  [[ -d "$potential_path" ]] && export HELPDIR="$potential_path"
