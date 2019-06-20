Plug 'rust-lang/rust.vim'

au BufRead,BufNewFile *.crs setf rust

let g:formatdef_rustfmt = '"rustfmt"'
let g:formatters_rust = ['rustfmt']
let g:ale_rust_cargo_use_clippy = 1
let g:ale_rust_cargo_check_all_targets = 1
