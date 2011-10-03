setopt correct_all

uncorrected_commands=(
  man
  mv
  cp
  mkdir
)

for command in $uncorrected_commands
  alias "$command=nocorrect $command"
