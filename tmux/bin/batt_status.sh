#!/bin/sh

unknown='❓'
battery='🔋'
power='🔌'

symbol=$unknown
percent='??'
time='?:??'

BAT0=/sys/class/power_supply/BAT0

if [ -f $BAT0/status ] && [ -f $BAT0/capacity ] && [ -f $BAT0/power_now ] && [ -f $BAT0/energy_now ]
then
  case $(cat $BAT0/status) in
    Discharging)
      symbol=$battery
      if [ "$(cat $BAT0/power_now)" = 0 ]
      then
        time='0:00'
      else
        minutes=$(( $(cat $BAT0/energy_now) * 60 / $(cat $BAT0/power_now) ))
        time=$(( minutes / 60 )):$(printf %02d $(( minutes % 60 )))
      fi
      ;;
    Charging)
      symbol=$power
      if [ "$(cat $BAT0/power_now)" = 0 ]
      then
        time='0:00'
      else
        minutes=$(( ($(cat $BAT0/energy_full) - $(cat $BAT0/energy_now)) * 60 / $(cat $BAT0/power_now) ))
        time=$(( minutes / 60 )):$(printf %02d $(( minutes % 60 )))
      fi
      ;;
  esac

  percent=$(cat $BAT0/capacity)
fi

if which pmset >/dev/null 2>/dev/null
then
  case $(pmset -g batt | grep -E -o "AC|Battery" -m 1) in
    AC) symbol=$power ;;
    Battery) symbol=$battery ;;
  esac
  percent=$(pmset -g batt | ack -o "[[:digit:]]{1,3}(?=%)")
  time=$(pmset -g batt | grep -E -o "[[:digit:]]{1,2}:[[:digit:]]{2}")
fi

if [ "$percent" -lt 5 ]
then
  color="#[fg=#ffffd7,bg=#d70000]"
fi

echo "$color$symbol $percent% $time"
