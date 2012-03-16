## Setup ZSH options
HISTFILE=$HOME/.zsh/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

my_options=(
  hist_ignore_all_dups # Don't add any duplicates to the history.
  hist_ignore_space    # Don't add lines that start with a space to the history.
  hist_verify          # Redisplay line after history completion before execution.
  inc_append_history   # Append to the history as commands are entered,
                       #   means new shells have recent history from still-open shells.
  extended_history     # Save timestamp and duration of commands as well.
  long_list_jobs       # List jobs in long format by default.
  auto_cd              # If a command matches a directory cd to it.
  multios              # Allow multiple files/pipes for redirections.
  prompt_subst         # Allow substitution in the prompt.
  auto_menu            # Show menu after second completion request
  auto_pushd           # Basically alias cd to pushd
)

for option in $my_options
  setopt $option

my_not_options=(
)

for option in $my_not_options
  unsetopt $option
