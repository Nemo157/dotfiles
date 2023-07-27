au BufRead,BufNewFile *.crs setf rust

au BufRead,BufNewFile *.rs let b:ale_linters = ['cargo-rubber']

let g:formatdef_rustfmt = '"rustfmt"'
let g:formatters_rust = ['rustfmt']
let g:ale_rust_cargo_use_clippy = 1
let g:ale_rust_cargo_check_all_targets = 1
