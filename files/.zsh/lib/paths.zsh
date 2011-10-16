## Add extra paths, only if they exist and only if they're not already added.
extra_paths=(
  $HOME/bin
  $HOME/node_modules/.bin
  /usr/local/avr/bin
  /usr/local/arm-eabi/bin
)

for extra_path in $extra_paths
  [[ -d $extra_path ]] && [[ ! $PATH =~ (^|.*:)$extra_path(:.*|$) ]] && export PATH=$PATH:$extra_path

extra_python_paths=(
  /usr/local/lib/python2.6/site-packages/
  /Library/Python/2.6/site-packages/
)

for extra_path in $extra_python_paths
  [[ -d $extra_path ]] && [[ ! $PYTHONPATH =~ (^|.*:)$extra_path(:.*|$) ]] && export PYTHONPATH=$extra_path:$PYTHONPATH

extra_perl_paths=(
  $HOME/bin/lib
)

for extra_path in $extra_perl_paths
  [[ -d $extra_path ]] && [[ ! $PERL5LIB =~ (^|.*:)$extra_path(:.*|$) ]] && export PERL5LIB=$extra_path:$PERL5LIB

extra_node_paths=(
  /usr/local/lib/node_modules
  $HOME/node_modules
)

for extra_path in $extra_node_paths
  [[ -d $extra_path ]] && [[ ! $NODE_PATH =~ (^|.*:)$extra_path(:.*|$) ]] && export NODE_PATH=$extra_path:$NODE_PATH
