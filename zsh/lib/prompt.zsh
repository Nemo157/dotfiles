setup_custom_prompt () {
  setup_vcs_info () {
    autoload -Uz vcs_info
    local vcs="$PR_GREEN%s"
    local branch="$PR_BLUE ᛘ $PR_YELLOW%b"
    local lights="%c%u"
    local action="$PR_BLUE | $PR_RED%a"

    local branch_format="%r"
    local vcs_prompt="${vcs}${branch}$PR_NO_COLOUR"
    local vcs_action_prompt="${vcs}${branch}${action}$PR_NO_COLOUR"
    local vcs_path="$PR_MAGENTA%R/$PR_GREEN%S$PR_NO_COLOUR"

    local staged_str="${PR_YELLOW} ●$PR_NO_COLOUR"
    local unstaged_str="${PR_RED} ●$PR_NO_COLOUR"

    zstyle ':vcs_info:*:prompt:*'     max-exports       3
    zstyle ':vcs_info:*:prompt:*'     check-for-changes true
    zstyle ':vcs_info:*:prompt:*'     stagedstr         $staged_str
    zstyle ':vcs_info:*:prompt:*'     unstagedstr       $unstaged_str
    zstyle ':vcs_info:*:prompt:*'     branchformat      $branch_format
    zstyle ':vcs_info:*:prompt:*'     formats           $vcs_path $vcs_prompt $lights
    zstyle ':vcs_info:*:prompt:*'     actionformats     $vcs_path $vcs_action_prompt $lights
    zstyle ':vcs_info:*:prompt:*'     nvcsformats       "%~"
  }

  setup_colours () {
    autoload colors zsh/terminfo
    colors

    for colour in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE BLACK; do
      eval PR_$colour='%{$fg[${(L)colour}]%}'
      eval PR_BG_$colour='%{$bg[${(L)colour}]%}'
    done

    PR_NO_COLOUR="%{$terminfo[sgr0]%}"
  }

  # This ensures the prompt doesn't move around, have lines duplicated etc. that
  # happens without the different prompt settings.  No idea why zsh is doing this,
  # but empirical testing has shown that this works (at least on OS X, zsh 5.0.2)
  # to keep a consistent 3-line prompt where the first is a blank spacer from the
  # last command.
  function zle-line-init {
    zle reset-prompt
    zle -R
  }

  function zle-line-finish {
    zle reset-prompt
    zle -R
  }

  function zle-keymap-select {
    zle reset-prompt
    zle -R
  }

  zle -N zle-line-init
  zle -N zle-line-finish
  zle -N zle-keymap-select

  setup_prompt () {
    setopt prompt_subst

    local start_first=""
    local user="%(!.$PR_RED.$PR_GREEN)%n"
    local host="$PR_GREEN%m"
    local whoami="${user}$PR_WHITE at ${host}$PR_NO_COLOUR$PR_BLUE"
    local fill='${(e)PR_FILLBAR}'
    local home_as_tilde='${${vcs_info_msg_0_}/$HOME/~}'
    local remove_final_dot='${'${home_as_tilde}'/%\/$PR_GREEN\.$PR_NO_COLOUR/$PR_NO_COLOUR}'
    local dir="${(%):-%${PR_PWDLEN}<...<${remove_final_dot}%<<}"
    local whereami="${dir}$PR_BLUE"
    local end_first="$PR_NO_COLOUR"

    local start_second=""
    local time='%D{%H:%M}'
    local return_value='${(%l:3:):-%?}'
    local extra_info="%(?.$PR_CYAN${time}. $PR_RED${return_value}!)"
    local lights='${vcs_info_msg_2_}'
    local marker='${${KEYMAP/vicmd/  }/(main|viins)/$PR_WHITE→ }'
    local end_second="$PR_NO_COLOUR"

    FIRSTLINE="${start_first}${whoami}    ${fill}${whereami}${end_first}"
    SECONDLINE="${start_second}${extra_info}${lights} ${marker}${end_second}"
    PROMPT="
  $FIRSTLINE
  $SECONDLINE"
  }

  setup_rprompt () {
    local start=' $PR_BLUE'
    local vcs_string='$vcs_info_msg_1_'
    local end='$PR_NO_COLOUR '

    RPROMPT="${start}${vcs_string}${end}"
  }

  setup_ps2 () {
    local start=""
    local continuation="$PR_BLUE($PR_GREEN%_$PR_BLUE)"
    local marker="%(!.$PR_RED!.)$PR_BLUE ->"
    local end="$PR_NO_COLOUR "

    PS2="${start}${continuation}${marker}${end}"
  }

  setup_colours
  setup_vcs_info
  setup_prompt
  setup_rprompt
  setup_ps2

  #usage: title short_tab_title looooooooooooooooooooooggggggg_windows_title
  #http://www.faqs.org/docs/Linux-mini/Xterm-Title.html#ss3.1
  #Fully support screen, iterm, and probably most modern xterm and rxvt
  #Limited support for Apple Terminal (Terminal can't set window or tab separately)
  function title {
    if [[ "$TERM" == "screen" ]]; then
      print -Pn "\ek$1\e\\" #set screen hardstatus, usually truncated at 20 chars
    elif [[ ($TERM =~ "^xterm") ]] || [[ ($TERM == "rxvt") ]] || [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
      print -Pn "\e]2;$2\a" #set window name
      print -Pn "\e]1;$1\a" #set icon (=tab) name (will override window name on broken terminal)
    fi
  }

  precmd () {
    title "%m: %15<..<%~%<<" "%m: %~"
    vcs_info 'prompt'

    ## Setup the path length for the prompt
    local TERMWIDTH
    (( TERMWIDTH = ${COLUMNS} - 1 ))

    PR_FILLBAR=""
    PR_PWDLEN=""

    local prompt="%n at %m     "
    local promptsize=${#${(%)prompt}}
    local pwdsize=${#${(%):-%~}}

    if [[ "$promptsize + $pwdsize" -gt $TERMWIDTH ]]; then
      (( PR_PWDLEN = $TERMWIDTH - $promptsize ))
    else
      PR_FILLBAR="\${(l.(($TERMWIDTH - ($promptsize + $pwdsize))).. .)}"
    fi
  }

  function preexec {
    local CMD=${1[(wr)^(*=*|sudo|ssh|-*)]} #cmd name only, or if this is sudo or ssh, the next cmd
    title "%m: $CMD" "%m: %100>...>$2%<<"
  }
}

if [ $commands[starship] ]
then
  eval "$(starship init zsh)" >/dev/null
else
  setup_custom_prompt
fi
