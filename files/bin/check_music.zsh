#!/usr/bin/env zsh

script_dir="$(dirname $0)"

base_dir="${1-/mnt/storage/Music}"
artist="${2-*}"
album="${3-*}"

allowed_music_files="*.(mp3|flac|m4a|ogg|wma|mpc)"

typeset -A warnings
warnings[Total]=0

typeset -a exiftool_args
exiftool_args+="-config"
exiftool_args+="$script_dir/check_music_exiftool_config.pl"
exiftool_args+="-s3"
exiftool_args+="-u"
exiftool_args+="-m"

last_status=
echo -en "" 1>&2

warning () {
  echo -en "\r\033[K" 1>&2
  echo "$1: ${2#$base_dir/}${3:+ }$3"
  echo -n "$last_status" 1>&2
  warnings[$1]=$(( ${warnings[$1]-0} + 1 ))
  warnings[Total]=$(( warnings[Total] + 1 ))
}

status () {
  last_status="$1"
  echo -en "\r\033[K$1" 1>&2
}

check_music_folder () {
  #set -A files (($base_dir*|$base_dir/${~artist}/*|$base_dir/${~artist}/${~album}/*|$base_dir/${~artist}/${~album}/*/*)(.N))
  #echo "Total files: ${#files}"
  status $base_dir
  for f in $base_dir/${~artist}(/N)
    check_artist "$f"
  for f in $base_dir/*(.N)
    check_base_folder_file "$f"
}

check_base_folder_file () {
  status $1
  case $(basename $1) in
    status.txt ) ;;
    * ) warning "Not allowed file in base music folder" $1 ;;
  esac
}

check_artist () {
  status $1
  for f in $1/${~album}(/N)
    check_album $f
  for f in $1/*(.N)
    check_artist_file $f

  if ! [[ -a "$1/folder.jpg" ]] {
    warning "Missing artist image" $1
  }
}

check_artist_file () {
  status $1
  case $(basename $1) in
    folder.jpg ) check_artist_image $1;;
    * ) warning "Not allowed file in artist folder" $1 ;;
  esac
}

check_artist_image () {
  local width="$(exiftool $exiftool_args -ImageWidth $1 2>/dev/null)"
  local height="$(exiftool $exiftool_args -ImageHeight $1 2>/dev/null)"
  if (($width != $height)) {
    warning "Artist image is not square" $1
  }
}

check_album () {
  status $1
  typeset -A artists
  local artists_list="$(exiftool $exiftool_args -r -p '$Artist' $1 2>/dev/null)"
  for artist in ${(f)artists_list}
    artists[$artist]=1

  local is_compilation=$((${#artists} - 1))

  for f in $1/*(/N)
    check_disc $f $is_compilation
  for f in $1/*(.N)
    check_album_file $f $is_compilation

  if ! [[ -a "$1/cover.jpg" || ! -z $(echo $1/*(/N)) ]] {
    warning "Missing album cover image" $1
  }
}

check_album_file () {
  status $1
  case $(basename $1) in
    cover.jpg | back.jpg | disc.jpg ) ;;
    ${~allowed_music_files} ) check_music_file $1 $2 ;;
    * ) warning "Not allowed file in album folder" $1 ;;
  esac
}

check_disc () {
  status $1
  for f in $1/*(/N)
    warning "Not allowed subfolders in album folder" $1
  for f in $1/*(.N)
    check_disc_file $f $2

  if ! [[ -a "$1/cover.jpg" ]] {
    warning "Missing disc cover image" $1
  }
}

check_disc_file () {
  status $1
  case $(basename $1) in
    cover.jpg | back.jpg | disc.jpg ) ;;
    ${~allowed_music_files} ) check_music_file $1 $2 ;;
    * ) warning "Not allowed file in disc folder" $1 ;;
  esac
}

check_music_file () {
  status $1
  typeset -a replaygain_tags

  replaygain_tags+="-ReplaygainAlbumGainClean"
  replaygain_tags+="-ReplaygainAlbumPeakClean"
  replaygain_tags+="-ReplaygainTrackGainClean"
  replaygain_tags+="-ReplaygainTrackPeakClean"

  local replaygain_count="$(exiftool $exiftool_args $replaygain_tags $1 | wc -w)"
  if ! [[ "$replaygain_count" == "4" ]] {
    warning "Replay gain data not found" $1
  }

  local is_compilation=$2
  local filename="$(basename "$1")"
  local potential_artist=''
  if (($is_compilation > 0)) {
    potential_artist='$Artist - '
  }
  local filename_format='$AlbumArtistOrArtist/$Album/$DiscTitleAndSlash$OnlyTrack - '$potential_artist'$TitleWithoutSlash'
  local preferred_filename="$(exiftool $exiftool_args -p $filename_format $1).${filename##*.}"
  preferred_filename="${preferred_filename//(:|\")/_}"
  if [[ "$preferred_filename" != "${1#$base_dir/}" ]] {
    warning "File is named wrong" $1 "should be $preferred_filename"
  }
}

print_summary () {
  echo
  echo "Summary"
  echo "======="
  for warning in ${(k)warnings}
    echo "$warning: $warnings[$warning]"
}

check_music_folder
print_summary
