#!/bin/sh

if which scutil >/dev/null
then
  vpn=$(scutil --nc list | grep "(Connected)" | sed -E "s/[[:space:]]{2,}/	/g" | cut -f 3 | tr -d "\"")
fi

if [ -n "$vpn" ]
then
  echo "🔐 $vpn"
fi
