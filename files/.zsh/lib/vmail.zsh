function mail() {
  if [[ -z "$1" ]]; then
    echo "You must specify an account" >&2
    return 1
  fi

  if [[ -x vmail ]]; then
    echo "vmail not installed" >&2
    return 3
  fi

  if [[ ! -e "$HOME/.vmailrc-$1" ]]; then
    echo "Account $1 doesn't exist" >&2
    return 2
  fi

  vmail -c "$HOME/.vmailrc-$1" ${@:2}
}

function mailsend() {
  if [[ -e "$HOME/.vmailrc-$1" ]]; then
    vmailsend -c "$HOME/.vmailrc-$1" ${@:2}
  fi
}

