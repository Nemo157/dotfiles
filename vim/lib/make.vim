" See http://stackoverflow.com/questions/15306371/vim-makefile-in-parent-directory
" This lets the makefile be in the directory above.
" TODO: Look into making this recursive (and decide if that is actually a good idea)
:let &makeprg = 'if [ -f Makefile ]; then make; else make -C ..; fi'
