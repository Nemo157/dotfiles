set nocompatible
filetype off " For vundle.

if !isdirectory($HOME."/.vim/bundle/vundle/.git")
  execute "!git clone 'git://github.com/gmarik/vundle.git' '".$HOME."/.vim/bundle/vundle'"
endif

set rtp+=$HOME/.vim/bundle/vundle/
call vundle#rc()

" Allows the bundle installation
Bundle 'gmarik/vundle'

" Better status line
Bundle 'Lokaltog/vim-powerline'

" Automatic lining up.
Bundle 'godlygeek/tabular'

" Tab-completion.
Bundle 'ervandew/supertab'

" Syntax checking
Bundle 'scooloose/syntastic'


" Auto completion popup
Bundle 'vim-scripts/AutoComplPop'

" Clang based C/C++ Completion
Bundle 'Rip-Rip/clang_complete'

" Better tabs
Bundle 'vim-scripts/Smart-Tabs'

" Language syntaxes.
Bundle 'Nemo157/glsl.vim'
Bundle 'plasticboy/vim-markdown'
Bundle 'kchmck/vim-coffee-script'
Bundle 'PProvost/vim-ps1'
Bundle 'dimituri/JSON.vim'
Bundle 'Nemo157/llvm.vim'
Bundle 'Nemo157/scala.vim'
Bundle 'Nemo157/rpn.vim'
Bundle 'tanob/mirah-vim'

" The Erlang plugin for Vim
Bundle 'jimenezrick/vimerl'

" Color scheme.
Bundle 'altercation/vim-colors-solarized'

" My general extensions that don't quite fit elsewhere
Bundle 'Nemo157/vim_extensions'

" JSHint for Javascript syntax checking
Bundle 'walm/jshint.vim'

" Indent guides
Bundle 'nathanaelkane/vim-indent-guides'

" Better indentation
Bundle 'vim-scripts/Smart-Tabs'

filetype plugin indent on " Automatically detect file types
syntax enable " Syntax highlighting

set nocompatible " Turn off Vi compatibility.

set tabstop=2 expandtab shiftwidth=2                    " Set 2-spaces instead of tabs.
set number                                              " Set line numbers on.
set autoindent                                          " Use smart indentation.
set background=dark                                     " Who would use a light terminal?
set showmatch                                           " Show matching brackets.
set ignorecase smartcase                                " Do smart case matching.
set incsearch                                           " Incremental search.
set nowrap                                              " Turn off line wrapping.
set sidescroll=1                                        " Set how far to scroll when moving off the edge.
set list listchars=precedes:<,extends:>,tab:»\ ,trail:\  " Show tabs, lines going off the edge and the end of lines.
set ruler                                               " Show current position in document at bottom right.
set scrolloff=5                                         " Scroll 5 lines from the top and bottom.
set sidescrolloff=10                                    " Scroll 30 characters from the edges.
set spell                                               " Spell checking on.
set undofile undodir=/tmp                               " Store persistent undo files in /tmp.
"set textwidth=80                                        " Set maximum width to 80 characters.
set suffixes+=.aux,.blg,.bbl,.log                       " Lower priority for tab completion
set cursorline                                          " Highlight the current line
set nofoldenable                                        " Turn them off until I bother learning them
set thesaurus+=~/.vim/thesaurus/mthesaur.txt            " Use the thesaurus from http://www.gutenberg.org/ebooks/3202
set bs=indent,eol,start                                 " Needed on Windows.
set mouse=                                              " Disable the mouse when using gvim.
set guifont=Consolas                                    " Use Consolas as the font in gvim.
set laststatus=2                                        " Always show the status line
set wildmenu                                            " Show a menu when tab-completing

let g:tex_flavor = "latex"                              " Give latex higher priority over tex.

let g:SuperTabDefaultCompletionType = "context"         " Set SuperTab to try and determine completion type automatically.
let g:SuperTabMappingForward = '<nul>'
let g:SuperTabMappingBackward = '<s-nul>'

silent! colorscheme solarized

let g:Powerline_cache_file = $HOME.'/.powerline.cache'
let g:Powerline_symbols = 'compatible'

" Set up Syntastic settings
let g:syntastic_check_on_open=1
let g:syntastic_auto_loc_list=1

" Set up vim-indent-guides settings
let g:indent_guides_guide_size = 1
let g:indent_guides_enable_on_vim_startup = 0
let g:indent_guides_start_level = 2

" set vim to chdir for each file
if exists('+autochdir')
  set autochdir
else
  autocmd BufEnter * silent! lcd %:p:h:gs/ /\\ /
endif

au BufNewFile,BufRead *.xaml setf xml

au FileType markdown\|rst\|tex\|plaintex setlocal textwidth=80
au FileType java\|c\|cpp\|glsl\|xml\|javascript\|json\|ps1\|vhdl setlocal tabstop=4 shiftwidth=4 noexpandtab

au GUIEnter * simalt ~x " Maximize the gvim window on Windows.

let mapleader = ","

map <leader>a= :Tabularize /=<CR>
map <leader>a: :Tabularize /:\zs<CR>
map <leader>a" :Tabularize /"<CR>

map <leader>p :diffput 1<CR>
map <leader>g :diffget 3<CR>
map <leader>d :diffup<CR>

map <leader>n :lnext<CR>
map <leader>p :lprev<CR>

" Have Vim jump to the last position when reopening a file
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

au BufReadPost Guardfile setf ruby
au BufRead,BufNewFile *.ll\|*.llvm setf llvm

au BufWritePost vimrc source ~/.vimrc

map <F5> :call SaveAndMake()<CR>
imap <F5> <C-o>:call SaveAndMake()<CR>

vnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>

command! W w
command! Wq wq
command! -bang Q q<bang>

command! Toh winc t | winc K | winc b | winc J | winc t
command! Tov winc t | winc H | winc b | winc L | winc t

command! -nargs=+ ReadPS read !powershell -NoProfile -NoLogo -Command "(<args>).ToString()"

func! SaveAndMake()
  exec "up"
  exec "make!"
endfunc
