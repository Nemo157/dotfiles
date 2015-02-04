au BufRead,BufNewFile *.kramdown setf mkd
au BufRead,BufNewFile *.xaml setf xml
au BufRead,BufNewFile Guardfile\|Gemfile\|Podfile setf ruby
au BufRead,BufNewFile *.ll\|*.llvm setf llvm

au FileType mkd\|markdown\|rst\|tex\|plaintex setlocal textwidth=80
au FileType java\|glsl\|xml\|ps1\|vhdl\|mason setlocal tabstop=4 shiftwidth=4 noexpandtab
au FileType c\|cpp setlocal tabstop=4 shiftwidth=4
au FileType javascript setlocal expandtab
au FileType coffee\|rust setlocal tabstop=2 shiftwidth=2

au BufWritePost vimrc source ~/.vimrc

