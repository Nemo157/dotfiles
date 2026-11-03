while IFS='' read -r line; do
  echo "$line"
  if IFS='' read -r line; then
    printf '\e[40m%s\e[K\e[0m\n' "$line"
  fi
done
