colorscheme eink2

set autochdir
set autoindent
set bs=indent,eol,start
set cedit=<Esc>
set colorcolumn=+1
set cursorline
set fillchars=vert:¦,diff:⸳
set ignorecase smartcase
set incsearch
set laststatus=2
set list listchars=precedes:<,extends:>,tab:»\ ,trail:\ 
set modeline
set modelines=10
set nofixendofline
set nofoldenable
set nowrap
set number
set ruler
set scrolloff=5
set showmatch
set sidescroll=1
set sidescrolloff=10
set signcolumn=yes
set spell
set suffixes+=.aux,.blg,.bbl,.log
set tabstop=2 expandtab shiftwidth=2
set textwidth=80
set thesaurus+=~/.local/share/vim/thesaurus/mthesaur.txt
set timeoutlen=1000
set ttimeoutlen=10
set undofile
set updatetime=100
set wildmenu

" See http://stackoverflow.com/questions/15306371/vim-makefile-in-parent-directory
" This lets the makefile be in the directory above.
" TODO: Look into making this recursive (and decide if that is actually a good idea)
:let &makeprg = 'if [ -f Makefile ]; then make; else make -C ..; fi'

let g:mapleader = ","

let g:airline_theme='base16'
let g:airline_powerline_fonts = 1
let g:airline_symbols = {}
" let g:airline_symbols.branch = ''
" let g:airline_symbols.readonly = ''
" let g:airline_symbols.linenr = '☰'
" let g:airline_symbols.maxlinenr = ''
" let g:airline_symbols.dirty='⚡'

let airline#extensions#ale#error_symbol = ' '
let airline#extensions#ale#warning_symbol = ' '
let airline#extensions#ale#show_line_numbers = 0

let g:ale_sign_error=''
let g:ale_sign_warning=''
let g:ale_sign_info=''
let g:ale_sign_style_error=''
let g:ale_sign_style_warning=''

let g:ale_c_parse_compile_commands=1
let g:ale_c_clangtidy_checks = ['*', '-hicpp-signed-bitwise']

let g:ale_rust_cargo_use_clippy = 1
let g:ale_rust_cargo_check_all_targets = 1

if filereadable('/Library/Developer/CommandLineTools/usr/lib/libclang.dylib')
  let g:clang_library_path='/Library/Developer/CommandLineTools/usr/lib/libclang.dylib'
endif

" Give latex higher priority over tex.
let g:tex_flavor = "latex"

let g:formatdef_rustfmt = '"rustfmt"'
let g:formatters_rust = ['rustfmt']

" Set SuperTab to try and determine completion type automatically.
let g:SuperTabDefaultCompletionType = "context"
let g:SuperTabMappingForward = '<nul>'
let g:SuperTabMappingBackward = '<s-nul>'

let g:fugitive_gitlab_domains = []

let g:gitgutter_sign_priority = 9
let g:gitgutter_override_sign_column_highlight = 0
let g:gitgutter_highlight_linenrs = 1
let g:gitgutter_sign_added = '|'
let g:gitgutter_sign_modified = '|'
let g:gitgutter_sign_removed = '|'
let g:gitgutter_sign_removed_first_line = '|'
let g:gitgutter_sign_modified_removed = '|'

let g:indent_guides_guide_size = 1
let g:indent_guides_enable_on_vim_startup = 0
let g:indent_guides_start_level = 2

let g:markdown_composer_binary='markdown-composer'
let g:markdown_composer_syntax_theme='solarized-dark'
let g:markdown_composer_custom_css=['http://thomasf.github.io/solarized-css/solarized-dark.min.css']

let g:EasyMotion_keys = 'uhetonaspg.c,r'

call lengthmatters#highlight_link_to('ColorColumn')

au FileType mkd\|markdown\|rst\|tex\|plaintex setlocal textwidth=80
au FileType java\|glsl\|xml\|ps1\|vhdl\|mason setlocal tabstop=4 shiftwidth=4 noexpandtab
au FileType c\|cpp setlocal tabstop=4 shiftwidth=4
au FileType coffee setlocal tabstop=2 shiftwidth=2
au FileType typescript setlocal expandtab sw=2 ts=2
au FileType javascript setlocal expandtab sw=2 ts=2
au FileType rust let b:ale_linters = ['cargo-rubber']

au BufRead,BufNewFile *.kramdown setf mkd
au BufRead,BufNewFile *.xaml setf xml
au BufRead,BufNewFile Guardfile\|Gemfile\|Podfile setf ruby
au BufRead,BufNewFile *.ll\|*.llvm setf llvm
au BufRead,BufNewFile *.sshtml setf html
au BufRead,BufNewFile *.es6 set filetype=javascript
au BufRead,BufNewFile *.crs setf rust
au BufRead,BufNewFile .yamllint setf yaml
au BufRead,BufNewFile vimrc setf vim
au BufRead,BufNewFile freshrc setf bash
au BufRead,BufNewFile freshrc.d/* setf bash

" Have Vim jump to the last position when reopening a file
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

map <leader>p :diffput 1<CR>
map <leader>g :diffget 3<CR>
map <leader>d :diffup<CR>

map <leader> <Plug>(easymotion-prefix)
map <Plug>(easymotion-prefix)w <Plug>(easymotion-bd-w)

map <leader>n :lnext<CR>
map <leader>p :lprev<CR>

vnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>

map <leader>a= :Tabularize /=<CR>
map <leader>a: :Tabularize /:\zs<CR>
map <leader>a" :Tabularize /"<CR>

" caps mistypings
command! W w
command! Wq wq
command! Wqa wqa
command! WQ wq
command! WQa wqa
command! WQA wqa
command! -bang Q q<bang>
command! -bang Qa q<bang>
command! -bang QA q<bang>

" Makes 3 splits go to horizontal layout
command! Toh winc t | winc K | winc b | winc J | winc t

" Makes 3 splits go to vertical layout
command! Tov winc t | winc H | winc b | winc L | winc t
