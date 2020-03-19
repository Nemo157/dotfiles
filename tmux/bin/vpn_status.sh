#!/bin/sh

if type scutil >/dev/null
then
  vpn=$(scutil --nc list | grep "(Connected)" | sed -E 's/.*"(.*)".*/\1/g')
fi

if type systemctl >/dev/null
then
  vpn=$(systemctl show 'openvpn-client@*' --property Id --value | sed -E 's/openvpn-client@(.*)\.service/\1/')
fi

if [ -n "$vpn" ]
then
  echo "🔐 $vpn"
fi
