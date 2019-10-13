setup_nvm() {
  if [[ ! -v NVM_DIR ]]
  then
    export NVM_DIR="$HOME/.nvm"
    if which brew >/dev/null
    then
      if [[ -s "$(brew --prefix nvm)/nvm.sh" ]]
      then
        source "$(brew --prefix nvm)/nvm.sh"
      fi
    elif [[ -s /usr/share/nvm/nvm.sh ]]
    then
      source /usr/share/nvm/nvm.sh
    fi
  fi
}

node() {
  setup_nvm
  /usr/bin/env node "$@"
}

npm() {
  setup_nvm
  /usr/bin/env npm "$@"
}
