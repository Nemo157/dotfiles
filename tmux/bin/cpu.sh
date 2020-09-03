#!/usr/bin/env zsh

percents=$(
  atop -PCPU -r \
  | grep '^CPU' \
  | cut -d' ' -f6,7,8,12 \
  | tail -n5 \
  | while read -r interval count cores idle
    do
      echo $(( 1 - (idle / (count * cores * interval * 1.0)) ))
    done
)

sparkline=$(
  blocks=(
    "▁"
    "▂"
    "▃"
    "▄"
    "▅"
    "▆"
    "▇"
    "█"
  )

  echo $percents | while read -r pct
  do
    block=$(( [#10] (pct * ${#blocks}) + 1 ))
    echo -n "${blocks[$block]}"
  done
)

color=$(
  colors=(
    "#[fg=#5f8700]"
    "#[fg=#af8700]"
    "#[fg=#d75f00]"
    "#[fg=#d70000]"
  )

  echo $percents | tail -n1 | while read -r pct
  do
    color=$(( [#10] (pct * ${#colors}) + 1 ))
    echo "${colors[$color]}"
  done
)

echo "  $color$sparkline"
