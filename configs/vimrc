" Load vundle before any other settings
set nocompatible
filetype off

let vundle_dir = $HOME."/.vim/bundle/vundle/.git"
if !isdirectory(vundle_dir)
  execute "!git clone 'git://github.com/gmarik/vundle.git' '".vundle_dir."'"
endif

set rtp+=$HOME/.vim/bundle/vundle/
call vundle#rc()

" Load generic Vim settings
let s:vimrc_libs = split(glob($HOME.'/.vim/lib/*.vim'), '\n')
for vimrc_lib in s:vimrc_libs
  if filereadable(vimrc_lib)
    execute 'source '.vimrc_lib
  endif
endfor

" Load machine specific Vim settings if they exist
let s:host_vimrc = $HOME.'/.vim/'.hostname().'.vimrc'
if filereadable(s:host_vimrc)
  execute 'source '.s:host_vimrc
endif

" Stuff still to put in separate files


let mapleader = ","

map <leader>n :lnext<CR>
map <leader>p :lprev<CR>

map <F5> :call SaveAndMake()<CR>
imap <F5> <C-o>:call SaveAndMake()<CR>

vnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>

command! -nargs=+ ReadPS read !powershell -NoProfile -NoLogo -Command "(<args>).ToString()"

func! SaveAndMake()
  exec "up"
  exec "make!"
endfunc

