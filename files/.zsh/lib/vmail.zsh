function mail() {
  if [[ -e "$HOME/.vmailrc-$1" ]]; then
    vmail -c "$HOME/.vmailrc-$1" ${@:2}
  fi
}

function mailsend() {
  if [[ -e "$HOME/.vmailrc-$1" ]]; then
    vmailsend -c "$HOME/.vmailrc-$1" ${@:2}
  fi
}

