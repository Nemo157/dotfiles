.configs
========

My configuration files.

Installation
------------

* Install necessary programs via package manager: tmux, git, zsh, vim

* Install ruby-install
* Install chruby

* Install and switch to ruby 2.0


    ruby-install ruby 2.0
    chruby 2.0

* Generate ssh key


    ssh-keygen
    
* Upload ssh key to github

* Clone configs and install


    git clone git@github.com:Nemo157/.configs ~/.configs
    git clone git@github.com:Nemo157/private_config ~/.configs/private
    cd ~/.configs
    rake install

* Copy out ssh key and remove backup folder


    mv ~/.ssh.backup/id_rsa* ~/.ssh
    rmdir ~/.ssh.backup
