export EC2_PRIVATE_KEY="$(ls $HOME/.ec2/pk-*.pem)"
export EC2_CERT="$(ls $HOME/.ec2/cert-*.pem)"
export AWS_CREDENTIALS_FILE="$HOME/.ec2/aws-credentials"

function () {
  set_locale () {
    if locale -a | grep "$1" >/dev/null ; then
      export LANG="$1"
      export LC_ALL="$1"
      true
    else
      false
    fi
  }

  set_locale en_NZ.UTF-8 || set_locale en_NZ.utf8 || set_locale en_US.UTF-8 || set_locale en_US.utf8
}

export EDITOR=vim

# grep
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='38;5;108'

## Add extra paths, only if they exist and only if they're not already added.
function () {
  prepend_if_exists () {
    [[ -d "$2" ]] && [[ ! "${(e)${:-\$$1}}" =~ "(^|.*:)$2(:.*|$)" ]] && export $1="$2:${(e)${:-\$$1}}"
  }

  append_if_exists () {
    [[ -d "$2" ]] && [[ ! "${(e)${:-\$$1}}" =~ "(^|.*:)$2(:.*|$)" ]] && export $1="${(e)${:-\$$1}}:$2"
  }

  export_if_exists () {
    [[ -d "$2" ]] && export $1="$2"
  }

  append_if_exists PATH "$HOME/bin"
  append_if_exists PATH "$HOME/node_modules/.bin"
  append_if_exists PATH "/usr/local/avr/bin"
  append_if_exists PATH "/usr/local/arm-eabi/bin"
  append_if_exists PATH "$HOME/.rvm/bin"

  append_if_exists PYTHONPATH "/usr/local/lib/python2.6/site-packages/"
  append_if_exists PYTHONPATH "/Library/Python/2.6/site-packages/"

  append_if_exists PERL5LIB "$HOME/bin/lib"

  append_if_exists NODE_PATH "/usr/local/lib/node_modules"
  append_if_exists NODE_PATH "$HOME/node_modules"

  append_if_exists CLASSPATH "/usr/local/Cellar/clojure-contrib/1.2.0/clojure-contrib.jar"

  export_if_exists JAVA_HOME "/System/Library/Frameworks/JavaVM.framework/Home"
  export_if_exists EC2_HOME "/usr/local/Cellar/ec2-api-tools/1.4.2.2/jars"
  export_if_exists EC2_AMITOOL_HOME "/usr/local/Cellar/ec2-ami-tools/1.3-45758/jars"
}
