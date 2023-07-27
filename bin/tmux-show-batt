#!/bin/sh

battery='🔋'
power='🔌'
unknown='❓'
one_hundred='💯'

symbol=$unknown
percent=''
time=''

BAT=/sys/class/power_supply/BAT?

if [ -f $BAT/status ] && [ -f $BAT/capacity ] && [ -f $BAT/power_now ] && [ -f $BAT/energy_now ]
then
  case $(cat $BAT/status) in
    Discharging)
      symbol=$battery
      if [ "$(cat $BAT/power_now)" = 0 ]; then
        time=''
      else
        minutes=$(( $(cat $BAT/energy_now) * 60 / $(cat $BAT/power_now) ))
        time=" $(( minutes / 60 )):$(printf %02d $(( minutes % 60 )))"
      fi
      ;;
    Charging)
      symbol=$power
      if [ "$(cat $BAT/power_now)" = 0 ]; then
        time=''
      else
        minutes=$(( ($(cat $BAT/energy_full) - $(cat $BAT/energy_now)) * 60 / $(cat $BAT/power_now) ))
        time=" $(( minutes / 60 )):$(printf %02d $(( minutes % 60 )))"
      fi
      ;;
    Full|'Not charging')
      symbol=$power
      time=''
      ;;
  esac

  percent=$(cat $BAT/capacity)
fi

if command -v pmset; then
  case $(pmset -g batt | grep -E -o "AC|Battery" -m 1) in
    AC)
      symbol=$power
      ;;
    Battery)
      symbol=$battery
      ;;
  esac
  percent=$(pmset -g batt | ack -o "[[:digit:]]{1,3}(?=%)")
  time=" $(pmset -g batt | grep -E -o "[[:digit:]]{1,2}:[[:digit:]]{2}")"
fi

if [ "$percent" -lt 5 ]; then
  color="#[fg=#ffffd7,bg=#d70000]"
elif [ "$percent" -lt 10 ]; then
  color="#[fg=#d75f00]"
elif [ "$percent" -lt 20 ]; then
  color="#[fg=#af8700]"
elif [ "$percent" -gt 95 ]; then
  color="#[fg=#5f8700]"
fi

# ThinkPad appears to cap out at 99%, just treat that as 100 for emoji purposes
if [ "$percent" -gt 98 ]
then
  percent="$one_hundred"
fi

if [ "$percent" ]; then
  percent="$percent%"
fi

echo "  $color$symbol$percent$time"
