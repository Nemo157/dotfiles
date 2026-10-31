if pkill mixxc; then
  exit 0
fi

exec niri msg action spawn -- "$(command -v mixxc)" --anchor l --anchor b --master --active --bar vertical --icon --close 100
