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

if [ "$frames" -gt 1 ]
then
  show "$wallpaper"
fi

if [ $RANDOM -gt 16384 ]
then
  args+=(-flop)
fi

if [ "$imgheight" -ge "$monheight" ] || [ "$imgwidth" -ge "$monwidth" ]
then
  if [ "$e" -lt 200 ]
  then
    # close enough, shrink to cover, cutting off a little of the image
    args+=(-resize "$size^")
  else
    # shrink to fit
    read -r imgwidth imgheight < <(run magick "$wallpaper" -resize "$size" -format '%w %h\n' info:-)
    echo "scaled: $imgwidth x $imgheight"
    args+=(-resize "$size")
  fi
fi

# round the edges and corners of smaller images by using a blurred alpha channel
args+=(
  -gravity center
  -compose Over -extent "$size"
  -channel A -blur 0x32 -level '50%,100%' +channel
  -extent "${imgwidth}x$imgheight"
)

border=$(( (monwidth - imgwidth) > (monheight - imgheight) ? (monwidth - imgwidth) : (monheight - imgheight) ))

if [ "$imgratio" -gt 1000 ]
then
  # wide images, just center them
  args+=(-gravity center)
else
  # skinny images, maybe show multiple

  options=(single-center)

  if [ "$(( monwidth - imgwidth * 4 - 40 ))" -gt 0 ]
  then
    options+=(quad-llrr-split quad-lrlr-split quad-llrr-edges quad-lrlr-edges)
  fi

  if [ "$(( monwidth - imgwidth * 3 - 30 ))" -gt 0 ]
  then
    options+=(triple-lll-split triple-lrl-split triple-lll-edges triple-lrl-edges)
  fi

  if [ "$(( monwidth - imgwidth * 2 - 30 ))" -gt 0 ]
  then
    options+=(double-lr-split double-ll-split double-lr-edges double-ll-edges)
    options+=(single-west single-east)
  fi

  option="$(printf '%s\n' "${options[@]}" | shuf -n1)"
  echo "chose $option from" "${options[@]}"

  case $option
  in
    quad-*) border=$(( monwidth - imgwidth * 4 )) ;;
    triple-*) border=$(( monwidth - imgwidth * 3 )) ;;
    double-*) border=$(( monwidth - imgwidth * 2 )) ;;
    single-*) border=$(( monwidth - imgwidth )) ;;
  esac

  case $option
  in
    quad-llll-*) args+=( \( +clone \) \( +clone \) \( +clone \) ) ;;
    quad-llrr-*) args+=( \( +clone \) \( +clone -flop \) \( +clone \) ) ;;
    quad-lrlr-*) args+=( \( +clone -flop \) \( +clone -flop \) \( +clone -flop \) ) ;;
    triple-lll-*) args+=( \( +clone \) \( +clone \) ) ;;
    triple-lrl-*) args+=( \( +clone -flop \) \( +clone -flop \) ) ;;
    double-ll-*) args+=( \( +clone \) ) ;;
    double-lr-*) args+=( \( +clone -flop \) ) ;;
  esac

  case $option
  in
    quad-*-split) args+=( +smush "$(( border / 5 ))" +smush "$(( border / 5 ))" +smush "$(( border / 5 ))") ;;
    quad-*-edges) args+=( +smush "$(( border / 3 ))" +smush "$(( border / 3 ))" +smush "$(( border / 3 ))") ;;
    triple-*-split) args+=( +smush "$(( border / 4 ))" +smush "$(( border / 4 ))" ) ;;
    triple-*-edges) args+=( +smush "$(( border / 2 ))" +smush "$(( border / 2 ))" ) ;;
    double-*-split) args+=( +smush "$(( border / 3 ))" ) ;;
    double-*-edges) args+=( +smush "$(( border ))" ) ;;
  esac

  case $option
  in
    single-west) args+=( -gravity west ) ;;
    single-east) args+=( -gravity east ) ;;
    *) args+=(-gravity center) ;;
  esac
fi

args+=(
  -compose Over -extent "$size"
)

# If we need to add a border to fit the monitor less reserved region,
# generate a blurred background to fill it

if [ "$border" -gt 0 ]
then
  args+=( \( +clone -channel RGBA -blur 0x1 \) )

  if [ "$border" -gt 4 ]; then args+=( \( +clone -channel RGBA -blur 0x2 \) ); fi
  if [ "$border" -gt 8 ]; then args+=( \( +clone -channel RGBA -blur 0x4 \) ); fi
  if [ "$border" -gt 16 ]; then args+=( \( +clone -channel RGBA -blur 0x8 \) ); fi
  if [ "$border" -gt 32 ]; then args+=( \( +clone -resize 25% ); fi
  if [ "$border" -gt 32 ]; then args+=( \( +clone -channel RGBA -blur 0x4 \) ); fi
  if [ "$border" -gt 64 ]; then args+=( \( +clone -channel RGBA -blur 0x8 \) ); fi
  if [ "$border" -gt 128 ]; then args+=( \( +clone -channel RGBA -blur 0x16 \) ); fi
  if [ "$border" -gt 256 ]; then args+=( \( +clone -channel RGBA -blur 0x32 \) ); fi
  if [ "$border" -gt 512 ]; then args+=( \( +clone -resize 25% ); fi
  if [ "$border" -gt 512 ]; then args+=( \( +clone -channel RGBA -blur 0x8 \) ); fi
  if [ "$border" -gt 1024 ]; then args+=( \( +clone -channel RGBA -blur 0x16 \) ); fi
  if [ "$border" -gt 512 ]; then args+=( -delete 0 -reverse -flatten -resize 400% \) ); fi
  if [ "$border" -gt 32 ]; then args+=( -delete 0 -reverse -flatten -resize 400% -blur 0x1 \) ); fi

  args+=( -reverse -flatten -alpha off )
fi


# Add black edges to fill any reserved region

args+=( -background black )

if [ "$monleft" -gt 0 ]
then
  args+=( -gravity west -splice "${monleft}x0" )
fi
if [ "$monright" -gt 0 ]
then
  args+=( -gravity east -splice "${monright}x0" )
fi
if [ "$montop" -gt 0 ]
then
  args+=( -gravity north -splice "0x$montop" )
fi
if [ "$monbottom" -gt 0 ]
then
  args+=( -gravity south -splice "0x$monbottom" )
fi


# Run the pipeline and send it to swww

run convert "${args[@]}" - | show -
