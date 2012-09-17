set nocompatible
filetype off " For vundle.

if !isdirectory(expand("~/.vim/bundle/vundle/.git"))
  !git clone git://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
endif

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" Allows the bundle installation
Bundle 'gmarik/vundle'

" Better status line
Bundle 'Lokaltog/vim-powerline'

" Automatic lining up.
Bundle 'godlygeek/tabular'

" Tab-completion.
Bundle 'ervandew/supertab'

" Clang based C/C++ Completion
Bundle "Rip-Rip/clang_complete"

" Language syntaxes.
Bundle 'Nemo157/glsl.vim'
Bundle 'plasticboy/vim-markdown'
Bundle 'kchmck/vim-coffee-script'
Bundle 'PProvost/vim-ps1'
Bundle 'Nemo157/llvm.vim'
Bundle 'Nemo157/scala.vim'

" Color scheme.
Bundle 'altercation/vim-colors-solarized'
Bundle 'vim-scripts/Zenburn'

" Highlighting debugging utility
Bundle 'kergoth/vim-HiLinkTrace'

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
set list listchars=precedes:<,extends:>,tab:»\ ,trail:▴ " Show tabs, lines going off the edge and the end of lines.
set ruler                                               " Show current position in document at bottom right.
set scrolloff=5                                         " Scroll 5 lines from the top and bottom.
set sidescrolloff=10                                    " Scroll 30 characters from the edges.
set spell                                               " Spell checking on.
set undofile undodir=/tmp                               " Store persistent undo files in /tmp.
set textwidth=80                                        " Set maximum width to 80 characters.
set suffixes+=.aux,.blg,.bbl,.log                       " Lower priority for tab completion
set cursorline                                          " Highlight the current line
set nofoldenable                                        " Turn them off until I bother learning them
set thesaurus+=~/.vim/thesaurus/mthesaur.txt            " Use the thesaurus from http://www.gutenberg.org/ebooks/3202
set bs=indent,eol,start                                 " Needed on Windows
set mouse=                                              " Disable mouse in gvim
set laststatus=2                                        " Always show the status line
set wildmenu                                            " Show a menu when tab-completing

let g:tex_flavor = "latex"                              " Give latex higher priority over tex.

let g:SuperTabDefaultCompletionType = "context"         " Set SuperTab to try and determine completion type automatically.
let g:SuperTabMappingForward = '<nul>'
let g:SuperTabMappingBackward = '<s-nul>'

silent! colorscheme solarized

au FileType markdown\|rst\|tex\|plaintex setlocal textwidth=80
au FileType java\|c\|cpp\|glsl setlocal tabstop=4 shiftwidth=4
au FileType vhdl setlocal noexpandtab tabstop=8 shiftwidth=8

let mapleader = ","

map <leader>a= :Tabularize /=<CR>
map <leader>a: :Tabularize /:\zs<CR>
map <leader>a" :Tabularize /"<CR>
map <leader>p :set invpaste<CR>

" Have Vim jump to the last position when reopening a file
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

au BufReadPost Guardfile setf ruby
au BufRead,BufNewFile *.ll\|*.llvm setf llvm

au BufWritePost vimrc source ~/.vimrc

map <F5> :call SaveAndMake()<CR>
imap <F5> <C-o>:call SaveAndMake()<CR>

vnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>

" Clear highlighting when <esc> is pressed
"nnoremap <esc> :noh<cr><esc>

command Wq wq
command -bang Q q<bang>

func! SaveAndMake()
  exec "up"
  exec "make!"
endfunc
