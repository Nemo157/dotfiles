#!/bin/sh

[ -f /sys/class/power_supply/BAT0/status ] || exit 1
[ -f /sys/class/power_supply/BAT0/energy_now ] || exit 1
[ -f /sys/class/power_supply/BAT0/energy_full ] || exit 1

case $(cat /sys/class/power_supply/BAT0/status) in
  Discharging)
    symbol='🔋'
    ;;
  Charging)
    symbol='🔌'
    ;;
esac

percent=$(cat /sys/class/power_supply/BAT0/capacity)

echo "$symbol $percent%"
