echo

trap exit SIGINT

options=("$@")
count=${#options[@]}
selected=0

while true
do
    for i in "${!options[@]}"
    do
        if [ "$i" = "$selected" ]
        then
          echo "  >  ${options[$i]}"
        else
          echo "     ${options[$i]}"
        fi
    done

    # leave the cursor sitting on the > marker
    echo -ne "\e[$((count - selected))A\e[2C"

    read -r -s -n1 key

    # finish resetting the cursor ready to overwrite the list
    [ "$selected" -gt 0 ] && echo -ne "\e[${selected}A"
    echo -ne "\e[2D" >&2

    case "$key" in
      "k" )
        selected=$(( selected == 0 ? selected : selected - 1 ))
        ;;
      "j" )
        selected=$(( selected == count - 1 ? selected : selected + 1 ))
        ;;
      "" )
        xdg-open "${options[$selected]}"
        tmux display-message "Opened ${options[$selected]}"
        ;&
      "q" | $'\e' )
        exit
        ;;
    esac
done
