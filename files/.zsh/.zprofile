export EC2_PRIVATE_KEY="$(ls $HOME/.ec2/pk-*.pem)"
export EC2_CERT="$(ls $HOME/.ec2/cert-*.pem)"
export AWS_CREDENTIALS_FILE="$HOME/.ec2/aws-credentials"
export LANG=en_NZ.utf8
export EDITOR=vim

# grep
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='38;5;108'

## Add extra paths, only if they exist and only if they're not already added.
extra_paths=(
  $HOME/bin
  $HOME/node_modules/.bin
  /usr/local/avr/bin
  /usr/local/arm-eabi/bin
  $HOME/.rvm/bin
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
[[ -d /usr/local/Cellar/clojure-contrib/1.2.0/clojure-contrib.jar ]] && export CLASSPATH=$CLASSPATH:/usr/local/Cellar/clojure-contrib/1.2.0/clojure-contrib.jar
[[ -d "/System/Library/Frameworks/JavaVM.framework/Home" ]] && export JAVA_HOME="/System/Library/Frameworks/JavaVM.framework/Home"
[[ -d "/usr/local/Cellar/ec2-api-tools/1.4.2.2/jars" ]] && export EC2_HOME="/usr/local/Cellar/ec2-api-tools/1.4.2.2/jars"
[[ -d "/usr/local/Cellar/ec2-ami-tools/1.3-45758/jars" ]] && export EC2_AMITOOL_HOME="/usr/local/Cellar/ec2-ami-tools/1.3-45758/jars"
