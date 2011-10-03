## Setup colour schemes
# tree
export LS_COLORS='di=38;5;108:fi=00:*svn-commit.tmp=31:ln=38;5;116:ex=38;5;186'

# ls
export LSCOLORS='cxexgxgxdxgxgxdbdbgbgb'

# grep
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='38;5;108'

# Setup the ls color option depending on Linux or BSD version ls
ls --color -d . &>/dev/null 2>&1 && alias ls='ls -F --color=auto' || alias ls='ls -FG'
