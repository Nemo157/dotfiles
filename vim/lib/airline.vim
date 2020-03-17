Plug 'vim-airline/vim-airline'
Plug 'Nemo157/vim-airline-themes'

let g:airline_theme='solarized'

if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

let g:airline_powerline_fonts = 1

" let g:airline_symbols.branch = ''
" let g:airline_symbols.readonly = ''
" let g:airline_symbols.linenr = '☰'
" let g:airline_symbols.maxlinenr = ''
" let g:airline_symbols.dirty='⚡'

let airline#extensions#ale#error_symbol = ' '
let airline#extensions#ale#warning_symbol = ' '
let airline#extensions#ale#show_line_numbers = 0
