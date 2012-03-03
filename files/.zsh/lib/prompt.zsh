setup_vcs_info () {
  autoload -Uz vcs_info
  local start="$PR_BLUE+-("
  local vcs="$PR_GREEN%s"
  local branch="$PR_BLUE : $PR_YELLOW%b"
  local lights="%c%u"
  local action="$PR_BLUE | $PR_RED%a"
  local end="$PR_BLUE)-+"

  local branch_format="%r"
  local vcs_prompt="${start}${vcs}${branch}${end}"
  local vcs_action_prompt="${start}${vcs}${branch}${action}${end}"
  local vcs_path="%R/$PR_GREEN%S"

  local staged_str="${PR_YELLOW}O "
  local unstaged_str="${PR_RED}O "

  zstyle ':vcs_info:*:prompt:*'     check-for-changes true
  zstyle ':vcs_info:*:prompt:*'     stagedstr         $staged_str
  zstyle ':vcs_info:*:prompt:*'     unstagedstr       $unstaged_str
  zstyle ':vcs_info:*:prompt:*'     branchformat      $branch_format
  zstyle ':vcs_info:*:prompt:*'     formats           $vcs_prompt        $vcs_path $lights
  zstyle ':vcs_info:*:prompt:*'     actionformats     $vcs_action_prompt $vcs_path $lights
  zstyle ':vcs_info:*:prompt:*'     nvcsformats       ""                 "%~"      ""
}

setup_colours () {
  autoload colors zsh/terminfo
  colors

  for colour in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE BLACK; do
    eval PR_$colour='%{$fg[${(L)colour}]%}'
  done

  PR_NO_COLOUR="%{$terminfo[sgr0]%}"
}

setup_prompt () {
  setopt prompt_subst

  local start_first=""
  local user="$PR_GREEN%(!.%SROOT%s.%n)"
  local host="$PR_GREEN%m"
  local term="$PR_GREEN%y"
  local whoami="$PR_BLUE+-(${user}$PR_WHITE at ${host}$PR_WHITE on ${term}$PR_BLUE)-+"
  local ruby_version='+-(${PR_YELLOW}Ruby Version: $PR_GREEN$(~/.rvm/bin/rvm-prompt 2> /dev/null)$PR_BLUE)-+'
  local fill='${(e)PR_FILLBAR}'
  local dir='${(%):-%${PR_PWDLEN}<...<${${${vcs_info_msg_1_}/$HOME/~}/%\/$PR_GREEN\./}%<<}'
  local whereami="$PR_BLUE+-($PR_MAGENTA${dir}$PR_BLUE)-+"
  local end_first=""

  local start_second=""
  local return_value="%(?.$PR_CYAN%D{%H:%M} .${PR_RED}! %? !$PR_BLUE )"
  local changes='$vcs_info_msg_2_'
  local marker="%(!.$PR_RED!.)$PR_WHITE->"
  local end_second="$PR_NO_COLOUR "

  PROMPT="
${start_first}${whoami}    ${ruby_version} ${fill}${whereami}${end_first}
${start_second}${return_value}${changes}${marker}${end_second}"
# time ${(e)PR_APM}$PR_YELLOW%D{%H:%M}\
}

setup_rprompt () {
  local start=' $PR_BLUE'
  local vcs_string='$vcs_info_msg_0_'
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

# Removes almost everything from the left prompt
simple_prompt () {
  PROMPT="%(!.$PR_RED!.)$PR_WHITE->$PR_NO_COLOUR "
}

# Removes EVERYTHING from the right prompt
no_right () {
  RPROMPT=""
}

# Puts a lot of info into the right prompt, useful with the simple_prompt.
complex_right () {
  local user="$PR_GREEN%(!.%SROOT%s.%n)"
  local host="$PR_GREEN%m"
  local term="$PR_GREEN%y"
  local whoami="${user}$PR_WHITE@${host}$PR_WHITE:${term}$PR_BLUE"
  local ruby_version='$PR_GREEN$(~/.rvm/bin/rvm-prompt 2> /dev/null)$PR_BLUE'
  local dir='%~$PR_BLUE'
  local whereami="$PR_MAGENTA${dir}"
  local vcs_string='$vcs_info_msg_0_'

  RPROMPT="$PR_BLUE${vcs_string} +-(${whereami} | ${ruby_version} | ${whoami})-+$PR_NO_COLOUR"
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

  local prompt="---(%n at %m on %y)--    --(Ruby Version: $(~/.rvm/bin/rvm-prompt 2> /dev/null))-- --()--"
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
