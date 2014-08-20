.configs
========

My configuration files.

Installation
------------


* Generate ssh key and upload ssh key to github
  ````
  ssh-keygen
  [[ -x $(which open) ]] && open https://github.com/settings/ssh || echo 'Browse to https://github.com/settings/ssh'
  ````

* Install necessary programs via package manager: tmux, git, zsh, vim, ruby-install, chruby

    ````sh
    # For gentoo
    sudo emerge -av tmux git zsh zsh-completion vim
    wget -O ruby-install-0.3.4.tar.gz https://github.com/postmodern/ruby-install/archive/v0.3.4.tar.gz
    tar -xzvf ruby-install-0.3.4.tar.gz
    cd ruby-install-0.3.4/
    sudo make install
    cd ..
    wget -O chruby-0.3.8.tar.gz https://github.com/postmodern/chruby/archive/v0.3.8.tar.gz
    tar -xzvf chruby-0.3.8.tar.gz
    cd chruby-0.3.8/
    sudo make install
    cd ..
    ````
    
    ````sh
    # For OS X
    ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
    brew install tmux git zsh zsh-completions vim ruby-install chruby
    ````

* Install and switch to ruby 2.0. Clone configs and install. Copy out ssh key and remove backup folder.

    
    ````
    ruby-install ruby 2.0
    chruby 2.0
    git clone git@github.com:Nemo157/.configs ~/.configs
    git clone git@github.com:Nemo157/private_config ~/.configs/private
    cd ~/.configs
    rake install
    mv ~/.ssh.backup/id_rsa* ~/.ssh
    rmdir ~/.ssh.backup
    ````
