#!/bin/sh

if which iwconfig >/dev/null
then
  ssid=$(iwconfig 2>/dev/null | awk 'START { code = 1 } match($0, /ESSID:".*"/) { print substr($0, RSTART + 7, RLENGTH - 8); code = 0 } END { exit(code) }')
  if [ -n "$ssid" ]
  then
    echo "📶 $ssid"
  fi
fi
