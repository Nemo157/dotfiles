au BufRead,BufNewFile *.es6 set filetype=javascript
au FileType typescript setlocal expandtab sw=2 ts=2
au FileType javascript setlocal expandtab sw=2 ts=2
let g:syntastic_javascript_checkers = ['standard', 'jscs', 'jshint']
