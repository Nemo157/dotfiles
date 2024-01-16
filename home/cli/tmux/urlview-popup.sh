trap exit SIGINT
trap "echo -e '\e[?25h'" EXIT

options=("$@")
count=${#options[@]}
selected=0

echo -e '\e[?25l'

while true
do
    for i in "${!options[@]}"
    do
        if [ "$i" = "$selected" ]
        then
          echo -e "\e[40m  \e[95m»\e[39m  ${options[$i]}\e[K\e[0m"
        else
          echo -e "     ${options[$i]}\e[K"
        fi
    done

    read -r -s -n1 key

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

    echo -ne "\e[${count}A"
done
