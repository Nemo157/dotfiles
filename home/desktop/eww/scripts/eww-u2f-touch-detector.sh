echo '{"requested":false}'
socat -u "UNIX-CONNECT:$XDG_RUNTIME_DIR/u2f-touch-detector.socket",forever - | while read -rn5 cmd
do
  case "$cmd" in
    "U2F_0")
      echo '{"requested":false}'
      ;;
    "U2F_1")
      echo '{"requested":true}'
      ;;
  esac
done
