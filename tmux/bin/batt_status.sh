#!/bin/sh

unknown='❓'
battery='🔋'
power='🔌'

symbol=$unknown
percent='??'
time='?:??'

BAT0=/sys/class/power_supply/BAT0

if [ -f $BAT0/status ]
then
  case $(cat $BAT0/status) in
    Discharging) symbol=$battery ;;
    Charging) symbol=$power ;;
  esac
fi

if [ -f $BAT0/capacity ]
then
  percent=$(cat $BAT0/capacity)
fi

if [ -f $BAT0/power_now ] && [ -f $BAT0/energy_now ]
then
  minutes=$(expr $(cat $BAT0/energy_now) '*' 60 / $(cat $BAT0/power_now))
  time=$(expr $minutes / 60):$(expr $minutes % 60)
fi

if which pmset >/dev/null 2>/dev/null
then
  case $(pmset -g batt | egrep -o "AC|Battery" -m 1) in
    AC) symbol=$power ;;
    Battery) symbol=$battery ;;
  esac
  percent=$(pmset -g batt | ack -o "[[:digit:]]{1,3}(?=%)")
  time=$(pmset -g batt | egrep -o "[[:digit:]]{1,2}:[[:digit:]]{2}")
fi

echo "$symbol $percent% $time"
