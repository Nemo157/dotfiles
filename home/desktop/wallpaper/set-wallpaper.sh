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

read -r frames imgfmt imgwidth imgheight < <(identify -format '%n %m %w %h\n' "$wallpaper")
echo "$wallpaper: $imgfmt $frames frames"

show() {
  args=(
    --outputs "$monitor"
    --transition-duration 2
    --transition-step 4
    --transition-angle "$(shuf -i0-359 -n1)"
    --transition-pos "0.$(shuf -i0-99 -n1),0.$(shuf -i0-99 -n1)"
    --resize=fit
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

blur-rules() {
    echo \( +clone -channel RGBA -blur 0x0 \)
    echo \( +clone -channel RGBA -blur 0x1 \)
    echo \( +clone -channel RGBA -blur 0x2 \)
    echo \( +clone -channel RGBA -blur 0x4 \)
    [ "$1" -gt 24 ] && echo \( +clone -channel RGBA -blur 0x8 \)
    [ "$1" -gt 56 ] && echo \( +clone -channel RGBA -blur 0x16 \)
    [ "$1" -gt 112 ] && echo \( +clone -channel RGBA -blur 0x32 \)
    [ "$1" -gt 240 ] && echo \( +clone -channel RGBA -blur 0x64 \)
    [ "$1" -gt 480 ] && echo \( +clone -channel RGBA -blur 0x128 \)
}

if [ "$frames" -eq 1 ]
then
  monwidth=$(( monwidth - monleft - monright ))
  monheight=$(( monheight - montop - monbottom ))
  monratio=$(( monwidth * 1000 / monheight ))
  imgratio=$(( imgwidth * 1000 / imgheight ))

  echo "$monitor: $monwidth x $monheight = $monratio/1000"
  echo "$wallpaper: $imgwidth x $imgheight = $imgratio/1000"

  e=$(( 2 * (imgratio < monratio ? (monratio - imgratio) : (imgratio - monratio)) * 1000 / (imgratio + monratio) ))

  echo "aspect ratio error: $e/1000"

  size="${monwidth}x$monheight"

  args=("$wallpaper")
  if [ "$imgheight" -ge "$monheight" ] || [ "$imgwidth" -ge "$monwidth" ]
  then
    if [ "$e" -lt 200 ]
    then
      # close enough, zoom to cover, cutting off a little of the border
      args+=(-resize "$size^")
    else
      # zoom to fit, adding a blurred border

      read -r scaledwidth scaledheight < <(magick "$wallpaper" -resize "$size" -format '%w %h\n' info:)

      if [ "$imgratio" -gt "$monratio" ]
      then
        border=$(( (monheight - scaledheight + 16) / 2 ))
        # shellcheck disable=SC2207
        args+=(
          -resize "$size"
          \(
            +clone
            -gravity north -extent "${monwidth}x8"
            -background none
            -gravity south -extent "${monwidth}x$border"
            $(blur-rules "$border")
            -reverse -flatten
            -alpha off
            -gravity north -extent "$size"
          \)
          \(
            -clone 0
            -gravity south -extent "${monwidth}x8"
            -background none
            -gravity north -extent "${monwidth}x$(( (monheight - scaledheight + 16) / 2 ))"
            $(blur-rules "$border")
            -reverse -flatten
            -alpha off
            -gravity south -extent "$size"
          \)
          \( -clone 0 -background transparent -gravity center -extent "$size" \)
          -delete 0
          -flatten
        )
      else
        border=$(( (monwidth - scaledwidth + 16) / 2 ))
        # shellcheck disable=SC2207
        args+=(
          -resize "$size"
          \(
            +clone
            -gravity west -extent "8x$monheight"
            -background none
            -gravity east -extent "$(( (monwidth - scaledwidth + 16) / 2 ))x$monheight"
            $(blur-rules "$border")
            -reverse -flatten
            -alpha off
            -gravity west -extent "$size"
          \)
          \(
            -clone 0
            -gravity east -extent "8x$monheight"
            -background none
            -gravity west -extent "$(( (monwidth - scaledwidth + 16) / 2 ))x$monheight"
            $(blur-rules "$border")
            -reverse -flatten
            -alpha off
            -gravity east -extent "$size"
          \)
          \( -clone 0 -background transparent -gravity center -extent "$size" \)
          -delete 0
          -flatten
        )
      fi
    fi
  else
    border=$(( (monheight - imgheight) > (monwidth - imgwidth) ? (monheight - imgheight) : (monwidth - imgwidth) ))
    # shellcheck disable=SC2207
    args+=(
      \(
        +clone
        \(
          +clone
          \( +level-colors white \)
          \( +clone -shave 8x8 +level-colors black \)
          -gravity center -compose Over -composite
        \)
        -gravity center -compose CopyOpacity -composite
      \)
      -background none
      -gravity center -compose Over -extent "$size"
      $(blur-rules "$border")
      -reverse -flatten
      -alpha off
    )
  fi

  args+=(-background black -gravity center -extent "$size")

  if [ "$monleft" -gt 0 ]
  then
    args+=(-gravity west -splice "${monleft}x0")
  fi
  if [ "$monright" -gt 0 ]
  then
    args+=(-gravity east -splice "${monright}x0")
  fi
  if [ "$montop" -gt 0 ]
  then
    args+=(-gravity north -splice "0x$montop")
  fi
  if [ "$monbottom" -gt 0 ]
  then
    args+=(-gravity south -splice "0x$monbottom")
  fi

  run convert "${args[@]}" - | show -
else
  show "$wallpaper"
fi
