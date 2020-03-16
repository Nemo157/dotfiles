" Color scheme.
Plug 'altercation/vim-colors-solarized'
Plug 'morhetz/gruvbox'
Plug 'https://bitbucket.org/kisom/eink.vim.git'

if $background == 'light'
  set background=light
else
  set background=dark
endif

colorscheme eink2
