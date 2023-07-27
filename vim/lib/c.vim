let g:ale_c_parse_compile_commands=1
let g:ale_c_clangtidy_checks = ['*', '-hicpp-signed-bitwise']

if filereadable('/Library/Developer/CommandLineTools/usr/lib/libclang.dylib')
  let g:clang_library_path='/Library/Developer/CommandLineTools/usr/lib/libclang.dylib'
endif
