" Syntax checking
Bundle 'scrooloose/syntastic'

" Set up Syntastic settings
let g:syntastic_check_on_open=1
let g:syntastic_auto_loc_list=1

let g:syntastic_c_config_file='.clang_complete'
if executable('clang')
  let g:syntastic_c_compiler='clang'
endif

let g:syntastic_cpp_config_file='.clang_complete'
if executable('clang++')
  let g:syntastic_cpp_compiler='clang++'
endif
