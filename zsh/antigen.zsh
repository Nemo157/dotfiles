if [[ ! -d "$HOME/.zsh/antigen" ]] then
  git clone https://github.com/zsh-users/antigen.git "$HOME/.zsh/antigen"
fi

source "$HOME/.zsh/antigen/antigen.zsh"

