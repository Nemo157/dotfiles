setopt correct_all
setopt dvorak

uncorrected_commands=(
  man
  mv
  cp
  mkdir
)

for command in $uncorrected_commands
  alias "$command=nocorrect $command"
