set textwidth=80
set colorcolumn=+1 " textwidth + 1
au VimEnter '*' call lengthmatters#highlight_link_to('ColorColumn')
