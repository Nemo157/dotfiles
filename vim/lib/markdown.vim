" Language syntax support
Plug 'plasticboy/vim-markdown'

" Realtime rendered preview
" PlugInclude
function! BuildComposer(info)
  if a:info.status != 'unchanged' || a:info.force
    if has('nvim')
      !cargo build --release --locked
    else
      !cargo build --release --locked --no-default-features --features json-rpc
    endif
  endif
endfunction
" /PlugInclude
Plug 'euclio/vim-markdown-composer', { 'do': function('BuildComposer') }

let g:markdown_composer_syntax_theme='solarized-dark'
let g:markdown_composer_custom_css=['http://thomasf.github.io/solarized-css/solarized-dark.min.css']
