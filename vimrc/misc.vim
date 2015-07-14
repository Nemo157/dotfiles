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

