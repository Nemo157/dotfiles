set tabstop=2 expandtab shiftwidth=2                     " Set 2-spaces instead of tabs.
set number                                               " Set line numbers on.
set autoindent                                           " Use smart indentation.
set showmatch                                            " Show matching brackets.
set ignorecase smartcase                                 " Do smart case matching.
set incsearch                                            " Incremental search.
set nowrap                                               " Turn off line wrapping.
set sidescroll=1                                         " Set how far to scroll when moving off the edge.
set list listchars=precedes:<,extends:>,tab:»\ ,trail:\  " Show tabs, lines going off the edge and the end of lines.
set ruler                                                " Show current position in document at bottom right.
set scrolloff=5                                          " Scroll 5 lines from the top and bottom.
set sidescrolloff=10                                     " Scroll 30 characters from the edges.
set spell                                                " Spell checking on.
set undofile undodir=/tmp                                " Store persistent undo files in /tmp.
set suffixes+=.aux,.blg,.bbl,.log                        " Lower priority for tab completion
set cursorline                                           " Highlight the current line
set nofoldenable                                         " Turn them off until I bother learning them
set thesaurus+=~/.vim/thesaurus/mthesaur.txt             " Use the thesaurus from http://www.gutenberg.org/ebooks/3202
set bs=indent,eol,start                                  " Needed on Windows.
set mouse=                                               " Disable the mouse when using gvim.
set guifont=Consolas                                     " Use Consolas as the font in gvim.
set laststatus=2                                         " Always show the status line
set wildmenu                                             " Show a menu when tab-completing
set modeline                                             " Allow modelines
set modelines=10
set cedit=<Esc>                                          " Use <Esc> to enter command line editing mode
set timeoutlen=1000
set ttimeoutlen=10
set fillchars=vert:¦,diff:⸳

let g:tex_flavor = "latex"                               " Give latex higher priority over tex.

set updatetime=100
