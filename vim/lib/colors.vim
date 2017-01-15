" Color scheme.
Plug 'altercation/vim-colors-solarized'
Plug 'https://bitbucket.org/kisom/eink.vim.git'

set background=dark

if exists("*strftime")
  if (strftime("%d") % 3 == 0)
    colorscheme solarized-eink
  elseif (strftime("%d") % 3 == 1)
    colorscheme solarized-min
  else
    colorscheme solarized
  endif
else
  colorscheme solarized
endif
