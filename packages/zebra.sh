while IFS='
do
  echo "$line"
  if IFS='
  then
     echo "[40m$line[K[0m"
  fi
done