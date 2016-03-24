function () {
  chruby_config_files=(
    "/usr/local/share/chruby/chruby.sh"
    "/usr/local/share/chruby/auto.sh"
  )

  for config_file in $chruby_config_files
    [[ -s $config_file ]] && source $config_file
}
