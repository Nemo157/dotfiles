# Load the prepared key mappings
# If you need to generate some of these simply run:
#     autoload zkbd; zkbd
function () {
  setup_bindings () {

    # Setup the bindings
    typeset -A bindings
    bindings[Left]=vi-backward-char
    bindings[Right]=vi-forward-char
    bindings[Home]=beginning-of-line
    bindings[End]=end-of-line
    bindings[Delete]=vi-delete-char
    bindings[CtrlSpace]=complete-word

    # Change to vi mode
    bindkey -v

    # Apply the bindings
    for k in ${(k)bindings}
      [[ -n ${key[$k]} ]] && bindkey "${key[$k]}" "${bindings[$k]}" || bindkey "$k" "${bindings[$k]}"
  }

  local map_file="$ZDOTDIR/.zkbd/$TERM-${${DISPLAY:t}:-$VENDOR-$OSTYPE}"
  [[ -f $map_file ]] && source $map_file && setup_bindings
}
