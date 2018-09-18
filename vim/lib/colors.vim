" Color scheme.
Plug 'altercation/vim-colors-solarized'
Plug 'morhetz/gruvbox'
Plug 'https://bitbucket.org/kisom/eink.vim.git'

set background=dark

if exists("*strftime")
  if (strftime("%d") % 4 == 0)
    colorscheme solarized-eink
  elseif (strftime("%d") % 4 == 1)
    colorscheme solarized-min
  elseif (strftime("%d") % 4 == 2)
    colorscheme gruvbox
  else
    colorscheme solarized
  endif
else
  colorscheme solarized
endif
