.configs
========

My configuration files.

Installation
------------


* Install main dotfiles
  ````
  FRESH_LOCAL_SOURCE=Nemo157/dotfiles bash <(curl -sL get.freshshell.com)
  ````

* Generate ssh key, upload to github and install private dotfiles (if you are me)
  ````
  ssh-keygen
  [[ -x $(which open) ]] && open https://github.com/settings/ssh || echo 'Browse to https://github.com/settings/ssh'
  fresh Nemo157/private_dotfiles
  ````
