#!/bin/sh

unknown='❓'
battery='🔋'
power='🔌'

symbol=$unknown
percent='??'
time='?:??'

if [ -f /sys/class/power_supply/BAT0/status ]
then
  case $(cat /sys/class/power_supply/BAT0/status) in
    Discharging) symbol=$battery ;;
    Charging) symbol=$power ;;
  esac
fi

if [ -f /sys/class/power_supply/BAT0/capacity ]
then
  percent=$(cat /sys/class/power_supply/BAT0/capacity)
fi

if which pmset >/dev/null
then
  case $(pmset -g batt | egrep -o "AC|Battery" -m 1) in
    AC) symbol=$power ;;
    Battery) symbol=$battery ;;
  esac
  percent=$(pmset -g batt | ack -o "[[:digit:]]{1,3}(?=%)")
  time=$(pmset -g batt | egrep -o "[[:digit:]]{1,2}:[[:digit:]]{2}")
fi

echo "$symbol $percent% $time"
