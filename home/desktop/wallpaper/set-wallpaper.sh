run() {
  cmd="$1"
  shift
  printf '%q' "$cmd" >&2
  printf ' %q' "$@" >&2
  printf '\n' >&2
  "$cmd" "$@"
}

monitor="$1"
wallpaper="$2"

read -r monwidth monheight monleft montop monright monbottom < <(
  hyprctl monitors -j | jq --arg monitor "$monitor" -r '.[] | select(.name == $monitor) | [.width, .height, .reserved[]] | join(" ")'
)

read -r frames imgfmt imgwidth imgheight < <(run magick "$wallpaper" -format '%n %m %w %h\n' info:-)
echo "$wallpaper: $imgfmt $frames frames"

show() {
  local args=(
    --outputs "$monitor"
    --transition-duration 2
    --transition-step 4
    --transition-angle "$(shuf -i0-359 -n1)"
    --transition-pos "0.$(shuf -i0-99 -n1),0.$(shuf -i0-99 -n1)"
    --no-resize
  )

  args+=(--transition-type)
  if [ "$frames" -eq 1 ]
  then
    args+=("$(printf 'simple\nwipe\nwave\ngrow\nouter\n' | shuf -n1)")
  else
    args+=(none)
  fi
  run swww img "${args[@]}" "$1"
}

if [ "$WALLPAPER_DUMB" -eq 1 ]
then
  show "$wallpaper"
  exit
fi

blur-rules() {
    if [ "$1" -eq 0 ]; then return; fi

    echo \( +clone -channel RGBA -blur 0x1 \)
    if [ "$1" -gt 4 ]; then echo \( +clone -channel RGBA -blur 0x2 \); fi
    if [ "$1" -gt 8 ]; then echo \( +clone -channel RGBA -blur 0x4 \); fi
    if [ "$1" -gt 16 ]; then echo \( +clone -channel RGBA -blur 0x8 \); fi
    if [ "$1" -gt 32 ]; then echo \( +clone -resize 25%; fi
    if [ "$1" -gt 32 ]; then echo \( +clone -channel RGBA -blur 0x4 \); fi
    if [ "$1" -gt 64 ]; then echo \( +clone -channel RGBA -blur 0x8 \); fi
    if [ "$1" -gt 128 ]; then echo \( +clone -channel RGBA -blur 0x16 \); fi
    if [ "$1" -gt 256 ]; then echo \( +clone -channel RGBA -blur 0x32 \); fi
    if [ "$1" -gt 512 ]; then echo \( +clone -resize 25%; fi
    if [ "$1" -gt 512 ]; then echo \( +clone -channel RGBA -blur 0x8 \); fi
    if [ "$1" -gt 1024 ]; then echo \( +clone -channel RGBA -blur 0x16 \); fi
    if [ "$1" -gt 512 ]; then echo -delete 0 -reverse -flatten -resize 400% \); fi
    if [ "$1" -gt 32 ]; then echo -delete 0 -reverse -flatten -resize 400%  -blur 0x1 \); fi

    echo -reverse -flatten -alpha off
}

reserved-rules() {
  echo -background black

  if [ "$monleft" -gt 0 ]
  then
    echo -gravity west -splice "${monleft}x0"
  fi
  if [ "$monright" -gt 0 ]
  then
    echo -gravity east -splice "${monright}x0"
  fi
  if [ "$montop" -gt 0 ]
  then
    echo -gravity north -splice "0x$montop"
  fi
  if [ "$monbottom" -gt 0 ]
  then
    echo -gravity south -splice "0x$monbottom"
  fi
}

monwidth=$(( monwidth - monleft - monright ))
monheight=$(( monheight - montop - monbottom ))
monratio=$(( monwidth * 1000 / monheight ))
imgratio=$(( imgwidth * 1000 / imgheight ))

echo "$monitor: $monwidth x $monheight = $monratio/1000"
echo "$wallpaper: $imgwidth x $imgheight = $imgratio/1000"

e=$(( 2 * (imgratio < monratio ? (monratio - imgratio) : (imgratio - monratio)) * 1000 / (imgratio + monratio) ))

echo "aspect ratio error: $e/1000"

size="${monwidth}x$monheight"

args=("$wallpaper" -background none)

if [ "$frames" -eq 1 ]
then
  if [ "$imgheight" -ge "$monheight" ] || [ "$imgwidth" -ge "$monwidth" ]
  then
    if [ "$e" -lt 200 ]
    then
      # close enough, zoom to cover, cutting off a little of the border
      border=0
      args+=(-resize "$size^")
    else
      # zoom to fit, adding a blurred border

      read -r scaledwidth scaledheight < <(run magick "$wallpaper" -resize "$size" -format '%w %h\n' info:-)
      echo "scaled: $scaledwidth x $scaledheight"

      args+=(-resize "$size")

      if [ "$imgratio" -gt "$monratio" ]
      then
        border=$(( (monheight - scaledheight + 16) / 2 ))
      else
        border=$(( (monwidth - scaledwidth + 16) / 2 ))
        if [ "$(( monwidth - scaledwidth * 2 ))" -gt 0 ] && [ "$RANDOM" -gt 16384 ]
        then
          border=$(( monwidth - scaledwidth * 2 ))
          args+=( \( +clone -resize "$size" )
          if [ $RANDOM -gt 16384 ]
          then
            args+=(-flop)
          fi
          args+=( \) )
          if [ $RANDOM -gt 16384 ]
          then
            args+=(-reverse)
          fi
          if [ $RANDOM -gt 10922 ]
          then
            args+=( +smush 0 )
          elif [ $RANDOM -gt 16384 ]
          then
            args+=( +smush "$(( border / 3 ))" )
          else
            args+=( +smush "$border" )
          fi
        fi
      fi

      if [ "$RANDOM" -gt 16384 ]
      then
        args+=(-gravity center)
      elif [ "$RANDOM" -gt 16384 ]
      then
        border=$(( border * 2 ))
        args+=(-gravity west)
      else
        border=$(( border * 2 ))
        args+=(-gravity east)
      fi

      args+=(
        -compose Over -extent "$size"
        -channel A -blur 0x8 -level '50%,100%' +channel
      )
    fi
  else
    border=$(( (monheight - imgheight) > (monwidth - imgwidth) ? (monheight - imgheight) : (monwidth - imgwidth) ))
    args+=(
      -virtual-pixel transparent
      -channel A -blur 0x32 -level '50%,100%' +channel
      -gravity center -compose Over -extent "$size"
    )
  fi

  # shellcheck disable=SC2207
  args+=(
    $(blur-rules "$border")
    $(reserved-rules)
  )

  run convert "${args[@]}" - | show -

elif [ "$frames" -lt 300 ]
then

  args+=(-coalesce)

  if [ "$imgheight" -ge "$monheight" ] || [ "$imgwidth" -ge "$monwidth" ]
  then
    if [ "$e" -lt 200 ]
    then
      # close enough, zoom to cover, cutting off a little of the border
      # shellcheck disable=SC2207
      args+=(
        -resize "$size^"
      )
    else
      # zoom to fit, adding a blurred border

      read -r scaledwidth scaledheight < <(run magick "$wallpaper"'[0]' -resize "$size" -format '%w %h\n' info:-)

      if [ "$imgratio" -gt "$monratio" ]
      then
        border=$(( (monheight - scaledheight + 16) / 2 ))
        # shellcheck disable=SC2207
        args+=(
          -resize "$size"
          \(
            -clone 0
            \(
              +clone
              -gravity north -extent "${monwidth}x8"
              -alpha on
              -gravity south -extent "${monwidth}x$border"
              $(blur-rules "$border")
              -gravity north -extent "$size"
            \)
            \(
              +clone
              -gravity south -extent "${monwidth}x8"
              -alpha on
              -gravity north -extent "${monwidth}x$border"
              $(blur-rules "$border")
              -gravity south -extent "$size"
            \)
          \)
          -insert 0
          null:
          -insert 1
          -gravity center
          -layers composite
        )
      else
        border=$(( (monwidth - scaledwidth + 16) / 2 ))
        # shellcheck disable=SC2207
        args+=(
          -resize "$size"
          \(
            -clone 0
            \(
              -clone 0
              -gravity west -extent "8x$monheight"
              -alpha on
              -gravity east -extent "${border}x$monheight"
              $(blur-rules "$border")
              -gravity west -extent "$size"
            \)
            \(
              -clone 0
              -gravity east -extent "8x$monheight"
              -alpha on
              -gravity west -extent "${border}x$monheight"
              $(blur-rules "$border")
              -gravity east -extent "$size"
            \)
            -delete 0
            -flatten
          \)
          -insert 0
          null:
          -insert 1
          -gravity center
          -layers composite
        )
      fi
    fi
  else
    border=$(( (monheight - imgheight) > (monwidth - imgwidth) ? (monheight - imgheight) : (monwidth - imgwidth) ))
    # shellcheck disable=SC2207
    args+=(
      -alpha on
      \(
        -clone 0
        \(
          +clone
          \(
            +clone
            \( +clone +level-colors white \)
            \( +clone -shave 8x8 +level-colors black \)
            -gravity center -compose Over -composite
          \)
          -gravity center -compose CopyOpacity -composite
        \)
        -gravity center -compose Over -extent "$size"
        $(blur-rules "$border")
      \)
      -insert 0
      null:
      -insert 1
      -gravity center -extent "$size"
      -layers composite
    )
  fi

  # shellcheck disable=SC2207
  args+=(
    $(reserved-rules)
  )

  tmp="$(mktemp --tmpdir "wallpaper-XXXXXX.gif")"
  run convert "${args[@]}" "$tmp"
  show "$tmp"
  rm "$tmp"

else

  show "$wallpaper"

fi
