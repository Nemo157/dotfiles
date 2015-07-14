unset RUBYOPT # Remove RUBYOPT cause of gentoo packagers retardation

extra_config_files=(
  $HOME/.zsh/lib/pc-specific/$(hostname -s).zlogin.zsh
  $HOME/.zsh/lib/os-specific/$(uname).zlogin.zsh
)

for config_file in $extra_config_files
  [[ -s $config_file ]] && source $config_file