## Set colour term if in gnome-terminal
if [[ "$COLORTERM" == "gnome-terminal" ]] then
  export TERM='xterm-256color'
fi

if [[ ! -d "$HOME/.zsh/antigen" ]] then
  git clone https://github.com/zsh-users/antigen.git "$HOME/.zsh/antigen"
fi

source "$HOME/.zsh/antigen/antigen.zsh"

antigen bundle zsh-users/zsh-syntax-highlighting

## Source all the config files.
for config_file ($ZDOTDIR/lib/*.zsh)
  source $config_file

extra_config_files=(
  $HOME/.zsh/vendor/syntax-highlighting/zsh-syntax-highlighting.zsh
  $HOME/.zsh/lib/pc-specific/$(hostname -s).zshrc.zsh
  $HOME/.zsh/lib/os-specific/$(uname).zshrc.zsh
)

for config_file in $extra_config_files
  [[ -s $config_file ]] && source $config_file
