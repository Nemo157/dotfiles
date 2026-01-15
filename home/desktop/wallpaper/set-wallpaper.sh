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

# Percentage chances to activate features
declare -A chances
chances=(
  [flop]=${FLOP_CHANCE:-50}
  [grayscale]=${GRAYSCALE_CHANCE:-25}
  [filter]=${FILTER_CHANCE:-25}
  [paint]=${PAINT_CHANCE:-50}
)

chance() {
  [ $(( RANDOM % 100 )) -lt "${chances[$1]}" ]
}

choose() {
  args=("$@")
  echo "${args[$RANDOM % ${#args[@]}]}"
}

# TODO: layer reserved area
read -r monwidth monheight monleft montop monright monbottom < <(
  niri msg -j outputs | jq --arg monitor "$monitor" -r '.[$monitor].logical | [.width, .height, 0, 0, 0, 0] | join(" ")'
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
    args+=(none --resize=no)
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

if chance flop
then
  args+=(-flop)
fi

if chance grayscale
then
  args+=(-type grayscale)
fi

# Permille monitor size of image to upscale instead of surrounding by a border
min_upscale=${MIN_UPSCALE:-800}

minheight=$(( monheight * min_upscale / 1000 ))
minwidth=$(( monwidth * min_upscale / 1000 ))
if [ "$imgheight" -ge "$minheight" ] || [ "$imgwidth" -ge "$minwidth" ]
then
  if [ "$e" -lt 200 ]
  then
    # close enough, size to cover, cutting off a little of the image
    echo "cut to fit"
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

vertborder=$(( monheight - imgheight ))
horizborder=$(( monwidth - imgwidth ))

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
    quad-*-split) horizborder=$(( (monwidth - imgwidth * 4) / 5 )) ;;
    quad-*-edges) horizborder=$(( (monwidth - imgwidth * 4) / 3 )) ;;
    triple-*-split) horizborder=$(( (monwidth - imgwidth * 3) / 4 )) ;;
    triple-*-edges) horizborder=$(( (monwidth - imgwidth * 3) / 2 )) ;;
    double-*-split) horizborder=$(( (monwidth - imgwidth * 2) / 3 )) ;;
    double-*-edges) horizborder=$(( monwidth - imgwidth * 2 )) ;;
    single-west|single-east) horizborder=$(( monwidth - imgwidth )) ;;
    single-center) horizborder=$(( (monwidth - imgwidth) / 2 )) ;;
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
    quad-*-split) tmp+=( +smush "$(( horizborder ))" +smush "$(( horizborder ))" +smush "$(( horizborder ))") ;;
    quad-*-edges) tmp+=( +smush "$(( horizborder ))" +smush "$(( horizborder ))" +smush "$(( horizborder ))") ;;
    triple-*-split) tmp+=( +smush "$(( horizborder ))" +smush "$(( horizborder ))" ) ;;
    triple-*-edges) tmp+=( +smush "$(( horizborder ))" +smush "$(( horizborder ))" ) ;;
    double-*-split) tmp+=( +smush "$(( horizborder ))" ) ;;
    double-*-edges) tmp+=( +smush "$(( horizborder ))" ) ;;
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

border=$(( vertborder > horizborder ? vertborder : horizborder ))
echo "border ${horizborder}x$vertborder: $border"

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
  if [ "$border" -gt 2048 ]; then args+=( \( +clone -channel RGBA -blur 0x32 \) ); fi
  if [ "$border" -gt 512 ]; then args+=( -delete 0 -reverse -flatten -resize 400% \) ); fi
  if [ "$border" -gt 32 ]; then args+=( -delete 0 -reverse -flatten -resize 400% -blur 0x1 \) ); fi

  args+=(
      -reverse -flatten -alpha off
    \)
    -delete 0
    +swap
  )
fi

if chance filter
then
  if chance paint
  then
    filters=(
      "-paint 6"
      "-spread 10 -noise 3"
      "-spread 15 -noise 3"
      "-spread 20 -noise 3"
    )
    # shellcheck disable=SC2207
    args+=($(choose "${filters[@]}"))
  else
   dithers=(
     checks
     o2x2
     o3x3
     o4x4
     o8x8
     h4x4a
     h6x6a
     h8x8a
     h4x4o
     h6x6o
     h8x8o
     h16x16o
     c5x5b
     c5x5w
     c6x6b
     c6x6w
     c7x7b
     c7x7w
   )
   args+=(-ordered-dither "$(choose "${dithers[@]}")")
  fi
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

run magick "${args[@]}" - | show -
