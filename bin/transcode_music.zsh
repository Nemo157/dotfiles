#!/usr/bin/env zsh

relpath () {
  [[ $# -ge 1 ]] && [[ $# -le 2 ]] || return 1
  local target=${${2:-$1}:A}
  local current=${${${2:+$1}:-$PWD}:A}
  local appendix=${target#/}
  local relative=''
  while appendix=${target#$current/}
    [[ $current != '/' ]] && [[ $appendix = $target ]]; do
    if [[ $current = $appendix ]]; then
      relative=${relative:-.}
      print ${relative#/}
      return 0
    fi
    current=${current%/*}
    relative="$relative${relative:+/}.."
  done
  relative+=${relative:+${appendix:+/}}${appendix#/}
  print $relative
}


help="Usage: $0 input_folder output_folder"

if [[ -z "$1" || -z "$2" ]] {
  echo $help
  exit 1
}

input_folder="$1"
output_folder="$2"

allowed_music_files="(mp3|flac|m4a|ogg|wma|mpc)"
ffmpeg_options=(-codec:a libmp3lame -q:a 2 -v warning -vn)

find_output_file () {
  local ext="$1"
  local relative_base="$2"
  case "$ext" in
    ${~allowed_music_files} ) echo "$output_folder/$relative_base.mp3" ;;
    * ) echo "$output_folder/$relative_base.$ext" ;;
  esac
}

verbose () {
}

process_file () {
  local input_file="$1"
  local relative_base="${$(relpath "$input_folder" "$input_file")%.*}"
  local ext="${$(relpath "$input_folder" "$input_file")##*.}"
  local output_file="$(find_output_file "$ext" "$relative_base")"
  if [[ -a "$output_file" ]]
  then
    verbose "$input_file matched $output_file which exists"
  else
    verbose "$input_file matched $output_file which doesn't exist"
    case "$ext" in
      ${~allowed_music_files} )
        echo "Transcoding $input_file to $output_file"
        mkdir -p "$(dirname "$output_file")"
        ffmpeg -i "$input_file" $ffmpeg_options "$output_file"
        if [[ $? -ne 0 ]]
        then
          echo "Error transcoding $input_file, deleting $output_file"
          echo "Command that failed: ffmpeg -i "'"'"$input_file"'"'" $ffmpeg_options "'"'"$output_file "'"'""
          rm $output_file
        fi
        ;;
      * )
        echo "Copying $input_file to $output_file"
        mkdir -p "$(dirname "$output_file")"
        cp "$input_file" "$output_file"
        ;;
    esac
  fi
}

for input_file in $input_folder/**/*(.)
do
  process_file $input_file
done

# ffmpeg -i "$file" -ab "$bitrate" -v warning -f mp3 -filter "volume=${volume}" -
