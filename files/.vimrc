set nocompatible
filetype off " For vundle.

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
" Brief help
" :BundleList          - list configured bundles
" :BundleInstall(!)    - install(update) bundles
" :BundleSearch(!) foo - search(or refresh cache first) for foo
" :BundleClean(!)      - confirm(or auto-approve) removal of unused bundles
"
" Allows the bundle installation
Bundle 'gmarik/vundle'
" Automatic lining up.
Bundle 'godlygeek/tabular'
" OpenGL Shading Language syntax.
Bundle 'Nemo157/glsl.vim'
" Color scheme.
Bundle 'altercation/vim-colors-solarized'
" Tab-completion.
Bundle 'ervandew/supertab'
" Dependency of new SnipMate.
Bundle 'MarcWeber/vim-addon-mw-utils'
" Dependency of new SnipMate.
Bundle 'tomtom/tlib_vim'
" Default snippets.
Bundle 'honza/snipmate-snippets'
" New SnipMate.
Bundle 'garbas/vim-snipmate'
" Bibtex snippets.
Bundle 'rbonvall/snipmate-snippets-bib'

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
set list listchars=precedes:⇽,extends:⇾,tab:»\ ,trail:▴ " Show tabs, lines going off the edge and the end of lines.
set ruler                                               " Show current position in document at bottom right.
set scrolloff=5                                         " Scroll 5 lines from the top and bottom.
set sidescrolloff=10                                    " Scroll 30 characters from the edges.
set spell                                               " Spell checking on.
set undofile undodir=/tmp                               " Store persistent undo files in /tmp.
set textwidth=80                                        " Set maximum width to 80 characters.
set suffixes+=.aux,.blg,.bbl,.log                       " Lower priority for tab completion

let g:tex_flavor = "latex"                              " Give latex higher priority over tex.
let g:SuperTabDefaultCompletionType = "context"         " Set SuperTab to try and determine completion type automatically.

colorscheme solarized

au FileType markdown\|rst\|tex\|plaintex setlocal textwidth=80
au FileType java\|c\|c++\|glsl setlocal tabstop=4 shiftwidth=4
au FileType vhdl setlocal noexpandtab tabstop=8 shiftwidth=8

" Have Vim jump to the last position when reopening a file
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

au BufWritePost vimrc source ~/.vimrc

map <F5> :call SaveAndMake()<CR>

vnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>

command Wq wq
command WQ wq
command Qw wq

func! SaveAndMake()
  exec "up"
  exec "make!"
endfunc
