" Language syntax support
Plug 'plasticboy/vim-markdown'

" Realtime rendered preview
function! BuildComposer(info) " Plug (hack for sorting)
  if a:info.status != 'unchanged' || a:info.force " Plug (hack for sorting)
    if has('nvim') " Plug (hack for sorting)
      !cargo build --release --locked \# Plug (hack for sorting)
    else " Plug (hack for sorting)
      !cargo build --release --locked --no-default-features --features json-rpc \# Plug (hack for sorting)
    endif " Plug (hack for sorting)
  endif " Plug (hack for sorting)
endfunction " Plug (hack for sorting)
Plug 'euclio/vim-markdown-composer', { 'do': function('BuildComposer') }

let g:markdown_composer_syntax_theme='solarized-dark'
let g:markdown_composer_custom_css=['http://thomasf.github.io/solarized-css/solarized-dark.min.css']
