# get the name of the ruby version we are using
function rvm_prompt_info() {
  ruby_version=$(~/.rvm/bin/rvm-prompt 2> /dev/null) || return
  echo "($ruby_version)"
}
