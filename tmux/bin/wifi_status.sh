#!/bin/sh

if which iwconfig >/dev/null 2>/dev/null
then
  ssid=$(iwconfig 2>/dev/null | awk 'START { code = 1 } match($0, /ESSID:".*"/) { print substr($0, RSTART + 7, RLENGTH - 8); code = 0 } END { exit(code) }')
fi

airport=/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport
if [ -x $airport ]
then
  ssid=$($airport -I | grep " SSID" | cut -d: -f 2 | tr -d "[[:space:]]")
fi

if [ -n "$ssid" ]
then
  echo "  📶$ssid"
fi
