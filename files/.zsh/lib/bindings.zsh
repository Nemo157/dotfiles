# Load the prepared key mappings
# If you need to generate some of these simply run:
#     autoload zkbd; zkbd
map_file="$HOME/.zsh/.zkbd/$TERM-${DISPLAY:-$VENDOR-$OSTYPE}"
[[ -f $map_file ]] && source $map_file

# Setup the bindings
typeset -A bindings
bindings[Left]=backward-char
bindings[Right]=forward-char
bindings[Home]=beginning-of-line
bindings[End]=end-of-line
bindings[Delete]=delete-char
bindings[CtrlSpace]=complete-word

# Change to vi mode
#bindkey -v

# Apply the bindings
for k in ${(k)bindings}
  [[ -n ${key[$k]} ]] && bindkey "${key[$k]}" "${bindings[$k]}" || bindkey "$k" "${bindings[$k]}"
