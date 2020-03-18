## unobtrusize autosuggestions

if [[ $background == 'light' ]]
then
  export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=14'
else
  export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=10'
fi

antigen bundle zsh-users/zsh-autosuggestions

bindkey '^n' autosuggest-accept
