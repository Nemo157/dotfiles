" Color scheme.
Plug 'altercation/vim-colors-solarized'
Plug 'https://bitbucket.org/kisom/eink.vim.git'

set background=dark

if exists("*strftime") && (strftime("%d") % 2)
  colorscheme solarized-eink
else
  colorscheme solarized
endif
