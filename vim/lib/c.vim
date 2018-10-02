" Clang based C/C++ Completion
Plug 'Rip-Rip/clang_complete'

let g:ale_c_parse_compile_commands=1

if filereadable('/Library/Developer/CommandLineTools/usr/lib/libclang.dylib')
  let g:clang_library_path='/Library/Developer/CommandLineTools/usr/lib/libclang.dylib'
endif
