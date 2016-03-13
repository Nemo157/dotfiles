" Syntax checking
Plug 'scrooloose/syntastic'

" Set up Syntastic settings
let g:syntastic_check_on_open=1
let g:syntastic_auto_loc_list=1

let g:syntastic_mode_map = { 'mode': 'active',
      \ 'active_filetypes': [],
      \ 'passive_filetypes': ['typescript', 'tex'] }
