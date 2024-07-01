artist="$(mpc list albumartist | shuf -n1)"
album="$(mpc list album albumartist "$artist" | shuf -n1)"
mpc clear >/dev/null
mpc findadd albumartist "$artist" album "$album"
mpc play
