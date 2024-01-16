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

monwidth=$(( monwidth - monleft - monright ))
monheight=$(( monheight - montop - monbottom ))
monratio=$(( monwidth * 1000 / monheight ))
imgratio=$(( imgwidth * 1000 / imgheight ))

echo "$monitor: $monwidth x $monheight = $monratio/1000"
echo "$wallpaper: $imgwidth x $imgheight = $imgratio/1000"

e=$(( 2 * (imgratio < monratio ? (monratio - imgratio) : (imgratio - monratio)) * 1000 / (imgratio + monratio) ))

echo "aspect ratio error: $e/1000"

show() {
  local args=(
    --outputs "$monitor"
    --transition-duration 2
    --transition-step 4
    --transition-angle "$(shuf -i0-359 -n1)"
    --transition-pos "0.$(shuf -i0-99 -n1),0.$(shuf -i0-99 -n1)"
  )

  args+=(--transition-type)
  if [ "$frames" -eq 1 ]
  then
    args+=("$(printf 'simple\nwipe\nwave\ngrow\nouter\n' | shuf -n1)" --resize=crop)
  else
    args+=(none --resize=fit)
  fi
  run swww img "${args[@]}" "$1"
}

if [ "${WALLPAPER_DUMB:-0}" -eq 1 ] || [ "$frames" -gt 1 ]
then
  show "$wallpaper"
  exit
fi

size="${monwidth}x$monheight"

args=("$wallpaper" -background none)

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
    imgheight="$monheight"
    imgwidth="$monwidth"
  else
    # shrink to fit
    read -r imgwidth imgheight < <(run magick "$wallpaper" -resize "$size" -format '%w %h\n' info:-)
    echo "scaled: $imgwidth x $imgheight"
    args+=(-resize "$size")
  fi
fi

# create a masked copy of the border of the image in index 0
args+=(
  \(
    +clone
    \(
      +clone
      +level-colors white
)
if [ "$imgheight" -eq "$monheight" ]
then
  args+=( \( +clone -shave 32x0 +level-colors black \) )
elif [ "$imgwidth" -ge "$monwidth" ]
then
  args+=( \( +clone -shave 0x32 +level-colors black \) )
else
  args+=( \( +clone -shave 32x32 +level-colors black \) )
fi
args+=(
      -background black
      -gravity center -compose Over -composite
      -extent "$size"
      -channel rgb -blur 0x16 -level '50%,100%' +channel
      -extent "${imgwidth}x$imgheight"
    \)
    -background transparent
    -gravity center -compose CopyOpacity -composite
  \)
  +swap
)

# round the edges and corners of smaller images by using a blurred alpha channel
# (but not the masked border)
args+=(
  \(
    +clone
    -gravity center
    -compose Over -extent "$size"
    -channel A -blur 0x32 -level '50%,100%' +channel
    -extent "${imgwidth}x$imgheight"
  \)
  +swap +delete
)

border=$(( (monwidth - imgwidth) > (monheight - imgheight) ? (monwidth - imgwidth) : (monheight - imgheight) ))

if [ "$imgratio" -gt 1000 ]
then
  # wide images, just center them
  args+=( -gravity center -compose Over -extent "$size" )
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

  tmp=()
  case $option
  in
    quad-llll-*) tmp+=( \( +clone \) \( +clone \) \( +clone \) ) ;;
    quad-llrr-*) tmp+=( \( +clone \) \( +clone -flop \) \( +clone \) ) ;;
    quad-lrlr-*) tmp+=( \( +clone -flop \) \( +clone -flop \) \( +clone -flop \) ) ;;
    triple-lll-*) tmp+=( \( +clone \) \( +clone \) ) ;;
    triple-lrl-*) tmp+=( \( +clone -flop \) \( +clone -flop \) ) ;;
    double-ll-*) tmp+=( \( +clone \) ) ;;
    double-lr-*) tmp+=( \( +clone -flop \) ) ;;
  esac

  case $option
  in
    quad-*-split) tmp+=( +smush "$(( border / 5 ))" +smush "$(( border / 5 ))" +smush "$(( border / 5 ))") ;;
    quad-*-edges) tmp+=( +smush "$(( border / 3 ))" +smush "$(( border / 3 ))" +smush "$(( border / 3 ))") ;;
    triple-*-split) tmp+=( +smush "$(( border / 4 ))" +smush "$(( border / 4 ))" ) ;;
    triple-*-edges) tmp+=( +smush "$(( border / 2 ))" +smush "$(( border / 2 ))" ) ;;
    double-*-split) tmp+=( +smush "$(( border / 3 ))" ) ;;
    double-*-edges) tmp+=( +smush "$(( border ))" ) ;;
  esac

  case $option
  in
    single-west) tmp+=( -gravity west ) ;;
    single-east) tmp+=( -gravity east ) ;;
    *) tmp+=( -gravity center ) ;;
  esac

  tmp+=( -compose Over -extent "$size" )

  # Because of the cloning and smushing, we have to apply the same series of
  # operations to the masked border and real image in parallel
  args+=(
    \( -clone 0 "${tmp[@]}" \)
    \( -clone 1 "${tmp[@]}" \)
    -delete 0-1
  )
fi

# If we need to add a border to fit the monitor less reserved region,
# generate a blurred background to fill it, using the masked border image
if [ "$border" -gt 0 ]
then
  args+=(
    \(
      -clone 0
  )

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

  args+=(
      -reverse -flatten -alpha off
    \)
    -delete 0
    +swap
  )
fi


# Add black edges to fill any reserved region

args+=( -background black -flatten )

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
