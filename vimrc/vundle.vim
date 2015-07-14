" Load vundle before any other settings
set nocompatible
filetype off

let vundle_dir = $HOME."/.vim/bundle/vundle/.git"
if !isdirectory(vundle_dir)
  execute "!git clone 'git://github.com/gmarik/vundle.git' '".vundle_dir."'"
endif

set rtp+=$HOME/.vim/bundle/vundle/
call vundle#rc()
