export svc=org.freedesktop.portal.Desktop
export obj=/org/freedesktop/portal/desktop
export int=org.freedesktop.portal.Settings
export ns=org.freedesktop.appearance
export key=color-scheme

toname() {
  while read -r value
  do
    case "$value" in
      0) echo light ;;
      1) echo dark ;;
      2) echo light ;;
      *)
        echo >&2 "unknown $key value $value"
        echo light
        ;;
    esac
  done
}

query() {
  busctl -j --user call $svc $obj $int Read ss $ns $key  | jq -Mc '
    .data[0].data.data
  ' | toname
}

watch() {
  busctl -j --user monitor $svc | jq --unbuffered -Mc '
    select(
      .type == "signal"
      and .path == env.obj
      and .interface == env.int
      and .member == "SettingChanged"
      and .payload.type == "ssv"
      and .payload.data[0] == env.ns
      and .payload.data[1] == env.key
    )
    | .payload.data[2].data
  ' | toname
}

while true
do
  if query
  then
    watch
  else
    echo light
  fi

  sleep 1
done
