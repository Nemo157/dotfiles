#!/usr/bin/env zsh

percents=$(
  atop -PMEM -r \
  | grep '^MEM' \
  | cut -d' ' -f8- \
  | tail -n5 \
  | while read -r total free cache buffer slab dirty_cache reclaimable_slab rest
    do
      echo $(( 1 - ((0.0 + free + cache + buffer - dirty_cache + reclaimable_slab) / total) ))
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

echo " $color$sparkline"
